import AVFoundation
import SwiftUI
import UserNotifications

struct ScheduledTripNotice: Equatable {
    let reminder: TripReminder
    let tripID: UUID
    let title: String
    let date: Date

    static var identifierPrefix: String {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["YUTO_UI_TEST_SUITE"], suite.hasPrefix("yuto.ui-test.") {
            return suite + ".notices."
        }
        #endif
        return "yuto.trip."
    }

    var identifier: String { Self.identifierPrefix + tripID.uuidString + "." + reminder.id.uuidString }

    @MainActor static func plan(_ store: TravelStore) -> [Self] {
        store.trips.filter { !$0.complete }.flatMap { trip -> [Self] in
            (trip.reminders ?? []).compactMap { reminder in
                guard let date = reminder.date(for: trip) else { return nil }
                return Self(reminder: reminder, tripID: trip.id,
                            title: store.catalog?.destination(trip.destination)?.shortName ?? "旅行", date: date)
            }
        }.sorted { $0.date < $1.date }
    }
}

@MainActor
@Observable
final class TripReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var latest: [ScheduledTripNotice] = []
    private var revision = 0
    private var syncing = false
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private(set) var pending: Set<String> = []
    private(set) var failure: String?
    private(set) var soundsEnabled = true

    func allow() async -> Bool {
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
            let settings = await center.notificationSettings()
            authorization = settings.authorizationStatus
            soundsEnabled = settings.soundSetting == .enabled
            return allowed
        } catch {
            failure = "系统未能开启通知，请稍后重试。"
            return false
        }
    }

    func refresh(_ plan: [ScheduledTripNotice]) {
        latest = plan
        revision += 1
        center.delegate = self
        guard !syncing else { return }
        syncing = true
        Task {
            var finished: Int
            repeat {
                finished = revision
                await reconcile(latest)
            } while finished != revision
            syncing = false
        }
    }

    private func reconcile(_ plan: [ScheduledTripNotice]) async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
        soundsEnabled = settings.soundSetting == .enabled
        let permitted = [.authorized, .provisional, .ephemeral].contains(authorization)
        let previous = await center.pendingNotificationRequests()
        let own = previous.filter { $0.identifier.hasPrefix(ScheduledTripNotice.identifierPrefix) }
        let room = max(0, 64 - (previous.count - own.count))
        let desired = permitted ? Array(plan.lazy.filter { $0.date > .now }.prefix(room)) : []
        let identifiers = Set(desired.map(\.identifier))
        let removed = own.map(\.identifier).filter { !identifiers.contains($0) }
        if !removed.isEmpty { center.removePendingNotificationRequests(withIdentifiers: removed) }
        var failed = false
        for item in desired {
            let kind = item.reminder.kind
            let content = UNMutableNotificationContent()
            content.title = item.title + " · " + kind.rawValue + "提醒"
            content.body = "第\(item.reminder.day)天，到\(kind.rawValue)时间了。"
            let spoken = item.reminder.voice && ReminderVoice.exists(kind)
            content.sound = spoken ? UNNotificationSound(named: UNNotificationSoundName(kind.soundName)) : .default
            let signature = "\(item.date.timeIntervalSince1970)|\(content.title)|\(content.body)|\(spoken)"
            if own.contains(where: { $0.identifier == item.identifier && $0.content.userInfo["revision"] as? String == signature }) { continue }
            content.userInfo = ["revision": signature]
            let time = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: false)
            do { try await center.add(UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)) }
            catch { failed = true }
        }
        if failed {
            failure = "部分提醒尚未排入系统，请重新检查通知权限后刷新。"
        } else if permitted && plan.filter({ $0.date > .now }).count > room {
            failure = "系统提醒名额已满，优先安排最近的提醒。下次打开悠途会继续更新。"
        } else { failure = nil }
        pending = Set(await center.pendingNotificationRequests().map(\.identifier))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

private struct TripReminderDelivery: ViewModifier {
    let store: TravelStore
    @Environment(\.scenePhase) private var phase
    @State private var scheduler = TripReminderScheduler()

    func body(content: Content) -> some View {
        let plan = ScheduledTripNotice.plan(store)
        content.environment(scheduler)
            .onChange(of: plan, initial: true) { _, newValue in scheduler.refresh(newValue) }
            .onChange(of: phase) { _, phase in if phase == .active { scheduler.refresh(plan) } }
    }
}

extension View {
    func tripReminderDelivery(store: TravelStore) -> some View { modifier(TripReminderDelivery(store: store)) }
}

// iOS can play short notification sounds from Library/Sounds even when the app is closed.
// Generate the four stock phrases on demand using the device's installed Mandarin voice.
@MainActor
final class ReminderVoice {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: CheckedContinuation<Bool, Never>?
    private var audio: AVAudioFile?
    private var timeout: Task<Void, Never>?
    private let temp = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".caf")
    private let destination: URL

    private static func file(_ kind: TripReminderKind) -> URL {
        URL.libraryDirectory.appendingPathComponent("Sounds").appendingPathComponent(kind.soundName)
    }
    static func exists(_ kind: TripReminderKind) -> Bool { FileManager.default.fileExists(atPath: file(kind).path) }

    private init(_ kind: TripReminderKind) { destination = Self.file(kind) }

    static func prepare(_ kind: TripReminderKind) async -> Bool {
        if exists(kind) { return true }
        return await ReminderVoice(kind).render(kind)
    }

    private func render(_ kind: TripReminderKind) async -> Bool {
        guard let voice = AVSpeechSynthesisVoice(language: "zh-CN") else { return false }
        let phrase = AVSpeechUtterance(string: "悠途提醒您，到\(kind.rawValue)时间了。")
        phrase.voice = voice
        phrase.rate = 0.43
        return await withCheckedContinuation { callback in
            completion = callback
            timeout = Task {
                try? await Task.sleep(for: .seconds(7))
                if !Task.isCancelled { finish(false) }
            }
            synthesizer.write(phrase) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                // Retain each buffer and serialize file writes in callback order.
                DispatchQueue.main.async { self.consume(pcm) }
            }
        }
    }

    private func consume(_ pcm: AVAudioPCMBuffer) {
        guard completion != nil else { return }
        do {
            if pcm.frameLength == 0 {
                guard let audio, audio.length > 0 else { finish(false); return }
                self.audio = nil
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.moveItem(at: temp, to: destination) }
                finish(true)
            } else {
                if audio == nil {
                    let settings: [String: Any] = [
                        AVFormatIDKey: kAudioFormatLinearPCM,
                        AVSampleRateKey: pcm.format.sampleRate,
                        AVNumberOfChannelsKey: pcm.format.channelCount,
                        AVLinearPCMBitDepthKey: 16,
                        AVLinearPCMIsFloatKey: false
                    ]
                    audio = try AVAudioFile(forWriting: temp, settings: settings, commonFormat: pcm.format.commonFormat,
                                            interleaved: pcm.format.isInterleaved)
                }
                try audio?.write(from: pcm)
            }
        } catch { finish(false) }
    }

    private func finish(_ success: Bool) {
        guard let callback = completion else { return }
        completion = nil
        timeout?.cancel()
        timeout = nil
        if !success { synthesizer.stopSpeaking(at: .immediate) }
        audio = nil
        try? FileManager.default.removeItem(at: temp)
        callback.resume(returning: success)
    }
}
