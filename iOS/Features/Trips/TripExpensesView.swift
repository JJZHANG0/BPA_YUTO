import SwiftUI

struct TripExpensesView: View {
    @Environment(TravelStore.self) private var store
    let trip: Trip
    @State private var adding = false
    @State private var removing: TripExpense?
    @State private var label = ""
    @State private var amount = ""

    var body: some View {
        let entries = trip.expenses ?? []
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("行程支出合计").font(.subheadline).foregroundStyle(YutoTheme.muted)
                    Text(TripExpense.yuan(entries.reduce(0) { $0 + $1.cents }))
                        .font(.title.bold().monospacedDigit())
                }
                Spacer()
                Button { label = ""; amount = ""; adding = true } label: {
                    Label("记一笔", systemImage: "plus").frame(minHeight: 44)
                }.font(.headline)
            }
            if entries.isEmpty {
                Text("记下交通、住宿和餐食费用，方便家人一起核对。")
                    .font(.subheadline).foregroundStyle(YutoTheme.muted)
            }
            ForEach(entries) { entry in
                Divider()
                HStack {
                    Text(entry.label)
                    Spacer()
                    Text(TripExpense.yuan(entry.cents)).monospacedDigit()
                    Button { removing = entry } label: {
                        Image(systemName: "minus.circle").frame(width: 44, height: 44)
                    }.accessibilityLabel("移除" + entry.label)
                }
            }
        }.travelPanel()
        .sheet(isPresented: $adding) {
            NavigationStack {
                Form {
                    TextField("费用名称", text: $label, prompt: Text("如：往返车票"))
                        .accessibilityIdentifier("expense-name")
                    LabeledContent("金额（元）") {
                        TextField("金额", text: $amount, prompt: Text("0.00"))
                            .multilineTextAlignment(.trailing).keyboardType(.decimalPad)
                            .accessibilityIdentifier("expense-amount")
                    }
                }.scrollContentBackground(.hidden).background(YutoTheme.paper)
                .navigationTitle("记一笔费用").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { adding = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存费用") { store.addExpense(label: label, amount: amount, to: trip.id); adding = false }
                            .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                      label.count > 30 || TripExpense.cents(from: amount) == nil)
                    }
                }
            }.presentationDetents([.medium, .large])
        }
        .confirmationDialog("移除这笔费用？", isPresented: Binding(
            get: { removing != nil }, set: { if !$0 { removing = nil } }
        ), titleVisibility: .visible, presenting: removing) { entry in
            Button("移除", role: .destructive) { store.removeExpense(entry.id, from: trip.id) }
            Button("取消", role: .cancel) {}
        }
    }
}
