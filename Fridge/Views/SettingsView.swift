import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shelves: [Shelf]
    @State private var showingClearConfirmation = false
    @State private var newShelfName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("冰箱隔层管理")) {
                    ForEach(shelves) { shelf in
                        Text(shelf.name)
                    }
                    .onDelete(perform: deleteShelves)

                    HStack {
                        TextField("新隔层名称", text: $newShelfName)
                        Button("添加") {
                            addShelf()
                        }
                        .disabled(newShelfName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section(header: Text("通知")) {
                    Button("重新授权通知权限") {
                        NotificationService.requestPermission()
                    }
                }

                Section(header: Text("数据管理")) {
                    Button("清空所有数据", role: .destructive) {
                        showingClearConfirmation = true
                    }
                }

                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .toolbar { EditButton() }
            .confirmationDialog("确认清空", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("清空所有数据", role: .destructive) {
                    clearAllData()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这将删除冰箱中的所有隔层和食材数据，此操作不可撤销。")
            }
        }
    }

    private func addShelf() {
        let trimmed = newShelfName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let shelf = Shelf(name: trimmed)
        modelContext.insert(shelf)
        newShelfName = ""
    }

    private func deleteShelves(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(shelves[index])
        }
    }

    private func clearAllData() {
        for shelf in shelves {
            modelContext.delete(shelf)
        }
        try? modelContext.save()
    }
}
