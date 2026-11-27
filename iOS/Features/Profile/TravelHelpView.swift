import CoreLocation
import MessageUI
import SwiftUI

struct TravelHelpView: View {
    @Environment(TravelStore.self) private var store
    @Environment(\.openURL) private var openURL
    @StateObject private var locator = HelpLocation()
    @State private var editing: HelpContact?
    @State private var recipientID: UUID?
    @State private var composer: HelpMessage?
    @State private var feedback = ""

    private var contacts: [HelpContact] { store.profile.helpContacts ?? [] }
    private var recipient: HelpContact? { contacts.first { $0.id == recipientID } ?? contacts.first }

    var body: some View {
        YutoPage {
            YutoScreenTitle(title: "出行求助", subtitle: "联系同行的人，把您所在的位置告诉家人。")
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    YutoSection(title: "求助联系人")
                    Spacer()
                    Button { editing = HelpContact(name: "", phone: "", role: "家人") } label: {
                        Label("添加", systemImage: "plus").frame(minHeight: 44)
                    }.accessibilityLabel("添加求助联系人")
                }
                if contacts.isEmpty {
                    Text("出发前存好家人、导游或旅行社的号码，途中可在这里拨打。")
                        .font(.body).foregroundStyle(YutoTheme.muted)
                }
                ForEach(contacts) { contact in
                    HStack(spacing: 8) {
                        Button { editing = contact } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name).font(.headline)
                                Text("\(contact.role) · \(contact.phone)").font(.subheadline).foregroundStyle(YutoTheme.muted)
                            }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }.buttonStyle(.plain).accessibilityHint("编辑联系人")
                        Button {
                            guard let phone = HelpContact.dialableNumber(contact.phone), let url = URL(string: "tel:" + phone) else { return }
                            openURL(url) { accepted in
                                if !accepted { feedback = "此设备无法拨号。联系电话为 " + contact.phone }
                            }
                        } label: {
                            Image(systemName: "phone.fill").frame(width: 46, height: 46)
                                .foregroundStyle(.white).background(YutoTheme.forest, in: Circle())
                        }.buttonStyle(.plain).accessibilityLabel("拨打" + contact.name)
                    }
                    if contact.id != contacts.last?.id { Divider() }
                }
            }.travelPanel()

            VStack(alignment: .leading, spacing: 12) {
                Label("把位置告诉家人", systemImage: "location.circle.fill")
                    .font(.title3.bold()).foregroundStyle(YutoTheme.forest)
                if let fix = locator.fix {
                    Text("定位于 " + fix.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline).foregroundStyle(YutoTheme.muted)
                    if contacts.count > 1 {
                        Picker("收件人", selection: Binding(get: { recipient?.id }, set: { recipientID = $0 })) {
                            ForEach(contacts) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                    let message = HelpMessage(location: fix, phone: recipient?.phone)
                    if MFMessageComposeViewController.canSendText() {
                        Button { composer = message } label: {
                            Label(recipient.map { "编辑短信给" + $0.name } ?? "编辑求助短信", systemImage: "message")
                                .frame(maxWidth: .infinity)
                        }.buttonStyle(YutoButtonStyle())
                    }
                    ShareLink(item: message.body) {
                        Label("选择应用分享位置", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }.buttonStyle(YutoButtonStyle(primary: !MFMessageComposeViewController.canSendText()))
                } else {
                    Text("点按定位后，可以预览求助短信，也可以选择其他应用分享。").foregroundStyle(YutoTheme.muted)
                }
                Button { locator.locate() } label: {
                    HStack {
                        if locator.locating { ProgressView() } else { Image(systemName: "location") }
                        Text(locator.locating ? "正在定位" : locator.fix == nil ? "获取我的位置" : "重新定位")
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(YutoButtonStyle(primary: locator.fix == nil)).disabled(locator.locating)
                if let problem = locator.problem {
                    Text(problem).font(.subheadline).foregroundStyle(YutoTheme.amberInk)
                    if locator.denied, let settings = URL(string: UIApplication.openSettingsURLString) {
                        Link("打开定位设置", destination: settings).frame(minHeight: 44)
                    }
                }
            }.travelPanel()
            DisclosureGroup("已在旅行社报名，如何改期或取消？") {
                Text("找到原订单上的服务方电话和订单号，询问最晚办理时间、取消费用和退款方式，再请对方发来书面确认。")
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }.travelPanel()
            VStack(alignment: .leading, spacing: 8) {
                Label("出行防骗提醒", systemImage: "hand.raised").font(.headline)
                Text("遇到临时改价或退款链接，请用原订单上的号码核实。银行卡密码和短信验证码只由本人保管。")
            }.travelPanel()
        }
        .navigationTitle("出行求助")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onDisappear { locator.cancel() }
        .sheet(item: $editing) { contact in
            HelpContactEditor(contact: contact, existing: contacts.contains { $0.id == contact.id }) { updated in
                var list = contacts
                if let index = list.firstIndex(where: { $0.id == updated.id }) { list[index] = updated }
                else { list.append(updated) }
                store.profile.helpContacts = list
            } remove: { store.profile.helpContacts = contacts.filter { $0.id != contact.id } }
        }
        .sheet(item: $composer) { draft in
            HelpMessageComposer(draft: draft) { result in
                composer = nil
                if result == .failed { feedback = "短信未能发送。您可以重新编辑，或使用其他应用分享位置。" }
            }
        }
        .alert("出行求助", isPresented: Binding(get: { !feedback.isEmpty }, set: { if !$0 { feedback = "" } })) {
            Button("好") { feedback = "" }
        } message: { Text(feedback) }
    }
}

private struct HelpContactEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var contact: HelpContact
    let existing: Bool
    let save: (HelpContact) -> Void
    let remove: () -> Void
    @State private var confirming = false
    private var phone: String? { HelpContact.dialableNumber(contact.phone) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("姓名或称呼", text: $contact.name)
                Picker("联系人身份", selection: $contact.role) {
                    ForEach(["家人", "导游", "旅行社客服", "其他"], id: \.self) { Text($0) }
                }
                TextField("电话号码", text: $contact.phone).textContentType(.telephoneNumber).keyboardType(.phonePad)
                if !contact.phone.isEmpty && phone == nil { Text("请输入有效的电话号码，可带国家或地区号。").foregroundStyle(YutoTheme.amberInk) }
                if existing { Button("删除联系人", role: .destructive) { confirming = true } }
            }
            .scrollContentBackground(.hidden).background(YutoTheme.paper)
            .navigationTitle(existing ? "编辑联系人" : "添加求助联系人").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        guard let phone else { return }
                        contact.name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        contact.phone = phone
                        save(contact)
                        dismiss()
                    }.disabled(phone == nil || contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("删除这位求助联系人？", isPresented: $confirming) {
                Button("删除", role: .destructive) { remove(); dismiss() }
            }
        }
    }
}

@MainActor
private final class HelpLocation: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var fix: CLLocation?
    @Published private(set) var problem: String?
    @Published private(set) var locating = false
    private let manager = CLLocationManager()
    private var timeout: Task<Void, Never>?
    var denied: Bool { [.denied, .restricted].contains(manager.authorizationStatus) }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func locate() {
        fix = nil
        problem = nil
        locating = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: requestFix()
        default: fail("定位权限未开启。您仍可拨打已存的联系电话。")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locating else { return }
        if denied { fail("定位权限未开启。您仍可拨打已存的联系电话。") }
        else if manager.authorizationStatus != .notDetermined { requestFix() }
    }

    private func requestFix() {
        timeout?.cancel()
        manager.requestLocation()
        timeout = Task {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            fail("暂时无法获取当前位置，请重试或拨打联系电话。")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locating else { return }
        guard let last = locations.last, last.horizontalAccuracy >= 0, abs(last.timestamp.timeIntervalSinceNow) < 120 else {
            fail("暂未获得近期位置，请重新定位。")
            return
        }
        fix = last
        cancel()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if locating { fail("定位未成功，请重试或直接联系家人。") }
    }

    func cancel() {
        timeout?.cancel()
        manager.stopUpdatingLocation()
        locating = false
    }

    private func fail(_ reason: String) { problem = reason; cancel() }
}

private struct HelpMessage: Identifiable {
    let id = UUID()
    let location: CLLocation
    let phone: String?

    var body: String {
        let lat = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.latitude)
        let lon = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), location.coordinate.longitude)
        return "我在旅途中需要帮助，请联系我。\n定位时间 " + location.timestamp.formatted(date: .abbreviated, time: .shortened) +
            "\n我的位置 https://maps.apple.com/?ll=" + lat + "," + lon
    }
}

private struct HelpMessageComposer: UIViewControllerRepresentable {
    let draft: HelpMessage
    let finish: (MessageComposeResult) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(finish: finish) }
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = draft.phone.map { [$0] }
        controller.body = draft.body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let finish: (MessageComposeResult) -> Void
        init(finish: @escaping (MessageComposeResult) -> Void) { self.finish = finish }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { finish(result) }
    }
}
