import SwiftUI
import SwiftData

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var shelves: [Shelf]
    var editingItem: FoodItem?

    @State private var name = ""
    @State private var quantity = 1
    @State private var hasExpiration = false
    @State private var expirationDate = Date()
    @State private var selectedShelfIndex = 0

    private var isEditing: Bool { editingItem != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("食材信息")) {
                    TextField("名称", text: $name)
                    Stepper("数量: \(quantity)", value: $quantity, in: 1...999)
                }

                Section(header: Text("保质期")) {
                    Toggle("设置过期日期", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("过期日期", selection: $expirationDate, displayedComponents: .date)
                    }
                }

                if !shelves.isEmpty {
                    Section(header: Text("所属隔层")) {
                        Picker("隔层", selection: $selectedShelfIndex) {
                            ForEach(Array(shelves.enumerated()), id: \.offset) { index, shelf in
                                Text(shelf.name).tag(index)
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑食材" : "添加食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let item = editingItem {
                    name = item.name
                    quantity = item.quantity
                    if let date = item.expirationDate {
                        hasExpiration = true
                        expirationDate = date
                    }
                    if let shelf = item.shelf, let idx = shelves.firstIndex(where: { $0.id == shelf.id }) {
                        selectedShelfIndex = idx
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let targetShelf: Shelf?
        if shelves.indices.contains(selectedShelfIndex) {
            targetShelf = shelves[selectedShelfIndex]
        } else {
            targetShelf = nil
        }

        if let item = editingItem {
            item.name = trimmedName
            item.quantity = quantity
            item.expirationDate = hasExpiration ? expirationDate : nil
            item.shelf = targetShelf
        } else {
            let newItem = FoodItem(
                name: trimmedName,
                expirationDate: hasExpiration ? expirationDate : nil,
                quantity: quantity,
                shelf: targetShelf
            )
            modelContext.insert(newItem)
        }

        try? modelContext.save()
        dismiss()
    }
}
