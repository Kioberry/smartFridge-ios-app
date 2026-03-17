import SwiftUI
import SwiftData

struct MealsView: View {
    @Query private var shelves: [Shelf]

    @State private var dishName: String = ""
    @State private var requiredIngredients: [String] = []
    @State private var missingIngredients: [String] = []
    @State private var recommendedRecipes: [RecommendedRecipe] = []
    @State private var isLoading = false
    @State private var alertMessage: AlertMessage?

    private var allItemNames: [String] {
        shelves.flatMap(\.items).map(\.name)
    }

    var body: some View {
        NavigationStack {
            Group {
                if shelves.isEmpty || allItemNames.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("智能餐食")
            .overlay {
                if isLoading { LoadingView() }
            }
            .alert(item: $alertMessage) { msg in
                Alert(title: Text("提示"), message: Text(msg.message), dismissButton: .default(Text("好的")))
            }
            .background(BrandColors.background)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 60))
                .foregroundColor(BrandColors.secondaryText)
            Text("还没有食材")
                .font(.title2.weight(.semibold))
            Text("先去「分析」页添加一些食材，AI才能为您推荐菜谱哦。")
                .font(.subheadline)
                .foregroundColor(BrandColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Recipe suggestions
                CardView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("智能菜谱推荐")
                            .font(.title2.weight(.bold))
                        Text("根据您冰箱里的现有食材，看看能做什么好吃的？")
                            .font(.subheadline)
                            .foregroundColor(BrandColors.secondaryText)

                        if !recommendedRecipes.isEmpty {
                            ForEach(recommendedRecipes) { recipe in
                                VStack(alignment: .leading) {
                                    Text(recipe.name).fontWeight(.semibold)
                                    Text(recipe.description).font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.bottom, 5)
                            }
                        }

                        Button(action: suggestRecipes) {
                            Text("给我一些灵感")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading)
                    }
                }

                // "I want to cook..."
                CardView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("我想做...")
                            .font(.title2.weight(.bold))
                        TextField("输入菜名，如西红柿炒蛋", text: $dishName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("分析缺少什么食材", action: findIngredients)
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(dishName.isEmpty || isLoading)

                        if !requiredIngredients.isEmpty {
                            Divider().padding(.vertical, 5)
                            Text("所需食材:").fontWeight(.semibold)
                            ForEach(requiredIngredients, id: \.self) { ingredient in
                                HStack {
                                    Text(ingredient)
                                    Spacer()
                                    Image(systemName: missingIngredients.contains(ingredient) ? "xmark.circle.fill" : "checkmark.circle.fill")
                                        .foregroundColor(missingIngredients.contains(ingredient) ? .red : .green)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func findIngredients() {
        guard !dishName.isEmpty, let apiKey = Secrets.geminiApiKey else {
            alertMessage = AlertMessage(message: String(localized: "API密钥缺失。"))
            return
        }
        isLoading = true
        let service = GeminiService(apiKey: apiKey)
        let items = allItemNames

        Task {
            do {
                let result = try await service.getRecipeIngredients(for: dishName, currentInventory: items)
                requiredIngredients = result.required
                missingIngredients = result.missing
                isLoading = false
            } catch {
                alertMessage = AlertMessage(message: String(localized: "分析菜谱失败: \(error.localizedDescription)"))
                isLoading = false
            }
        }
    }

    private func suggestRecipes() {
        guard let apiKey = Secrets.geminiApiKey else {
            alertMessage = AlertMessage(message: String(localized: "API密钥缺失。"))
            return
        }
        isLoading = true
        let service = GeminiService(apiKey: apiKey)
        let items = allItemNames

        Task {
            do {
                let result = try await service.suggestRecipes(from: items)
                recommendedRecipes = result
                isLoading = false
            } catch {
                alertMessage = AlertMessage(message: String(localized: "推荐菜谱失败: \(error.localizedDescription)"))
                isLoading = false
            }
        }
    }
}
