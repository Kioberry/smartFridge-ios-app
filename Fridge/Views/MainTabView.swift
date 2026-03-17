import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            AnalyzeView()
                .tabItem {
                    Label("分析", systemImage: "sparkles")
                }

            InventoryView()
                .tabItem {
                    Label("库存", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            MealsView()
                .tabItem {
                    Label("餐食", systemImage: "fork.knife.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .tint(BrandColors.primary)
    }
}
