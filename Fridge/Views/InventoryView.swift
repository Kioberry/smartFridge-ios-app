import SwiftUI
import SwiftData

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shelves: [Shelf]
    @State private var showingAddItem = false
    @State private var searchText = ""

    private var allItems: [FoodItem] {
        shelves.flatMap(\.items)
    }

    private var filteredShelves: [Shelf] {
        if searchText.isEmpty { return shelves }
        return shelves.compactMap { shelf in
            let filtered = shelf.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            if filtered.isEmpty { return nil }
            // Return the shelf as-is; we filter display in the ForEach
            return shelf
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if shelves.isEmpty || allItems.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("库存清单")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddEditItemView(shelves: shelves)
            }
            .onAppear {
                NotificationService.requestPermission()
                NotificationService.scheduleExpirationNotifications(for: allItems)
            }
            .background(BrandColors.background)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "refrigerator")
                .font(.system(size: 60))
                .foregroundColor(BrandColors.secondaryText)
            Text("冰箱是空的")
                .font(.title2.weight(.semibold))
            Text("去「分析」页拍张照片，或点击右上角 + 手动添加食材。")
                .font(.subheadline)
                .foregroundColor(BrandColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredShelves) { shelf in
                Section(header: Text(shelf.name).font(.headline)) {
                    ForEach(filteredItems(for: shelf)) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                if item.quantity > 1 {
                                    Text("数量: \(item.quantity)")
                                        .font(.caption)
                                        .foregroundColor(BrandColors.secondaryText)
                                }
                            }
                            Spacer()
                            if let days = item.daysUntilExpiration {
                                Text(expirationText(for: days))
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(expirationColor(for: days).opacity(0.15))
                                    .foregroundColor(expirationColor(for: days))
                                    .cornerRadius(8)
                            } else {
                                Text("日期未知").font(.caption).foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(item)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            NavigationLink {
                                AddEditItemView(shelves: shelves, editingItem: item)
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "搜索食材")
    }

    private func filteredItems(for shelf: Shelf) -> [FoodItem] {
        if searchText.isEmpty { return shelf.items }
        return shelf.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func expirationText(for days: Int) -> LocalizedStringKey {
        if days < 0 { return "已过期" }
        if days == 0 { return "今天过期" }
        return "还剩 \(days) 天"
    }

    private func expirationColor(for days: Int) -> Color {
        if days < 0 { return .red }
        else if days <= 3 { return .orange }
        else { return .green }
    }
}
