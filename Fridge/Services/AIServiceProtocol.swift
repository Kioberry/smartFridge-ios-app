import Foundation

protocol AIServiceProtocol: Sendable {
    func analyzeFridgeImage(imageData: Data, shelvesConfig: [String]) async throws -> [(shelfName: String, itemNames: [String])]
    func getExpirationDates(for items: [String]) async throws -> [(name: String, expiresInDays: Int)]
    func getRecipeIngredients(for dish: String, currentInventory: [String]) async throws -> (required: [String], missing: [String])
    func suggestRecipes(from inventory: [String]) async throws -> [RecommendedRecipe]
}
