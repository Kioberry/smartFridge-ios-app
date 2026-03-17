import Foundation

struct RecommendedRecipe: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
}
