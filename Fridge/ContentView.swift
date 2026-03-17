import SwiftUI
import SwiftData

@main
struct SmartFridgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Shelf.self, FoodItem.self])
    }
}

struct ContentView: View {
    @Query private var shelves: [Shelf]
    @State private var showWelcomeScreen = true

    var body: some View {
        ZStack {
            if showWelcomeScreen {
                WelcomeView(onStart: {
                    withAnimation {
                        showWelcomeScreen = false
                    }
                })
            } else {
                MainTabView()
            }
        }
        .onAppear {
            if !shelves.isEmpty {
                showWelcomeScreen = false
            }
        }
    }
}
