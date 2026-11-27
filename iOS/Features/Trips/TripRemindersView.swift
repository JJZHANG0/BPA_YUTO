import SwiftUI
import UserNotifications

struct TripRemindersView: View {
    let tripID: UUID
    @Environment(TravelStore.self) private var store
    @Environment(TripReminderScheduler.self) private var scheduler
    @Environment(\.openURL) private var openURL
    @State private var editing: TripReminder?

    private var trip: Trip? { store.trips.first { $0.id == tripID } }

    var body: some View {
        YutoPage {
            if let trip {
                TravelCover(place: store.catalog?.destination(trip.destination), title: "一路有人提醒",
                            subtitle: trip.displayDates)
                if scheduler.authorization == .denied {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("本机通知已关闭").font(.headline)
                        Text("在系统设置中打开悠途通知，才能按时收到提醒。")
                        Button("打开通知设置") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }.buttonStyle(YutoButtonStyle(primary: false))
                    }.travelPanel()
                }
                if let failure = scheduler.failure {
                    Text(failure).font(.subheadline).foregroundStyle(YutoTheme.amberInk)
                }
                let reminders = (trip.reminders ?? []).sorted {
                    ($0.day, $0.hour, $0.minute) < ($1.day, $1.hour, $1.minute)
                }
                if reminders.isEmpty {
                    Text("为出发、集合、用餐或返程选个时间，悠途会在这台手机上提醒您。")
                        .font(.body).foregroundStyle(YutoTheme.muted)
                }
                ForEach(reminders) { reminder in
                    Button { editing = reminder } label: {
                        TravelMenuRow(icon: reminder.kind.icon, title: reminder.kind.rawValue + "提醒",
                                      detail: detail(reminder, trip: trip)).travelPanel()
                    }.buttonStyle(.plain)
                    .accessibilityLabel(reminder.kind.rawValue + "提醒")
                    .accessibilityValue(detail(reminder, trip: trip))
                    .accessibilityIdentifier("trip-reminder-row")
                }
                if !trip.complete {
                    Button {
                        let firstFuture = (1...max(trip.days, 1)).first { day in
                            TripReminder(kind: .depart, day: day, hour: 9, minute: 0, voice: true).date(for: trip).map { $0 > .now } ?? false
                        } ?? trip.days
                        editing = TripReminder(kind: .depart, day: firstFuture, hour: 9, minute: 0, voice: true)
                    } label: {
                        Label("添加提醒", systemImage: "plus").frame(maxWidth: .infinity)
                    }.buttonStyle(YutoButtonStyle()).accessibilityIdentifier("add-trip-reminder")
                }
            }
        }
        .navigationTitle("行程提醒").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $editing) { reminder in
            if let trip { TripReminderEditor(trip: trip, initial: reminder) }
        }
    }

    private func detail(_ reminder: TripReminder, trip: Trip) -> String {
        let time = String(format: "%02d:%02d", reminder.hour, reminder.minute)
        let prefix = "第\(reminder.day)天 \(time) · "
        guard !trip.complete else { return prefix + "行程已完成" }
        guard let date = reminder.date(for: trip) else { return prefix + "已超出当前行程，请调整" }
        guard date > .now else { return prefix + "时间已过" }
        guard let item = ScheduledTripNotice.plan(store).first(where: { $0.reminder.id == reminder.id }),
              scheduler.pending.contains(item.identifier) else { return prefix + "尚未排入系统" }
        if !scheduler.soundsEnabled { return prefix + "已安排 · 系统声音关闭" }
        return prefix + (reminder.voice && ReminderVoice.exists(reminder.kind) ? "已安排语音提醒" : "已安排通知铃声")
    }
}

private struct TripReminderEditor: View {
    let trip: Trip
    @State private var draft: TripReminder
    @State private var time: Date
    @State private var working = false
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(TravelStore.self) private var store
    @Environment(TripReminderScheduler.self) private var scheduler

    init(trip: Trip, initial: TripReminder) {
        self.trip = trip
        _draft = State(initialValue: initial)
        _time = State(initialValue: Calendar.current.date(bySettingHour: initial.hour, minute: initial.minute, second: 0, of: .now) ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("提醒事项", selection: $draft.kind) {
                        ForEach(TripReminderKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("行程日期", selection: $draft.day) {
                        ForEach(1...max(1, trip.days), id: \.self) { day in
                            let date = Calendar.current.date(byAdding: .day, value: day - 1, to: trip.date) ?? trip.date
                            Text("第\(day)天 · " + date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))).tag(day)
                        }
                    }
                    DatePicker("提醒时间", selection: $time, displayedComponents: .hourAndMinute)
                    Toggle("使用语音提醒", isOn: $draft.voice)
                } header: { Text("提醒安排") } footer: {
                    Text("调整出发日期时，提醒会随行程顺延。提醒声音遵循手机的通知与静音设置。")
                }
                if let message { Text(message).foregroundStyle(YutoTheme.amberInk) }
                if (trip.reminders ?? []).contains(where: { $0.id == draft.id }) {
                    Button("删除这条提醒", role: .destructive) {
                        store.removeReminder(draft.id, from: trip.id)
                        dismiss()
                    }
                }
            }
            .disabled(working).scrollContentBackground(.hidden).background(YutoTheme.paper)
            .navigationTitle("编辑提醒").navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(working)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) {
                    if working { ProgressView().accessibilityLabel("正在设置提醒") }
                    else { Button("保存提醒") { Task { await save() } } }
                }
            }
        }
    }

    private func save() async {
        guard !working else { return }
        draft.hour = Calendar.current.component(.hour, from: time)
        draft.minute = Calendar.current.component(.minute, from: time)
        guard let date = draft.date(for: trip), date > .now else { message = "请选择行程内尚未到来的时间。"; return }
        working = true
        defer { working = false }
        guard await scheduler.allow() else { message = "需要在系统设置中允许悠途发送通知，才能保存提醒。"; return }
        if draft.voice { _ = await ReminderVoice.prepare(draft.kind) }
        guard store.saveReminder(draft, for: trip.id) else { message = "行程时间已变更，请重新选择。"; return }
        dismiss()
    }
}
