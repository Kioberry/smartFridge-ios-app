import Foundation

struct GeminiService: AIServiceProtocol, Sendable {
    private let apiKey: String
    private let apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyzeFridgeImage(imageData: Data, shelvesConfig: [String]) async throws -> [(shelfName: String, itemNames: [String])] {
        let base64Image = imageData.base64EncodedString()
        let shelfNames = shelvesConfig.joined(separator: ", ")
        let prompt = """
        Analyze this image of a refrigerator. The fridge is divided into these shelves: \(shelfNames). \
        Identify all food items on each shelf. Return the result in a strict JSON format like this: \
        [{"shelfName": "Shelf Name", "items": ["Food Item 1", "Food Item 2"]}]
        """

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt], ["inlineData": ["mimeType": "image/jpeg", "data": base64Image]]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]

        let responseData = try await performRequest(payload: payload)
        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw NetworkError.cannotParseResponse
        }
        let decoded = try JSONDecoder().decode([DecodableShelf].self, from: jsonData)
        return decoded.map { (shelfName: $0.shelfName, itemNames: $0.items) }
    }

    func getExpirationDates(for items: [String]) async throws -> [(name: String, expiresInDays: Int)] {
        guard !items.isEmpty else { throw NetworkError.emptyInput }
        let prompt = """
        Estimate a reasonable expiration date for the following food items based on common shelf life. \
        Today's date is \(Date().formatted(date: .long, time: .omitted)). \
        Food list: \(items.joined(separator: ", ")). \
        Return the result in a strict JSON format like this: [{"name": "Food Name", "expiresInDays": 7}]
        """

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]

        let responseData = try await performRequest(payload: payload)
        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw NetworkError.cannotParseResponse
        }

        let decoded = try JSONDecoder().decode([DecodableFoodExpiration].self, from: jsonData)
        return decoded.map { (name: $0.name, expiresInDays: $0.expiresInDays) }
    }

    func getRecipeIngredients(for dish: String, currentInventory: [String]) async throws -> (required: [String], missing: [String]) {
        let prompt = """
        I want to cook: "\(dish)". My current inventory is: \(currentInventory.joined(separator: ", ")). \
        List all main ingredients needed and which ones I am missing. \
        Return in a strict JSON format: {"required": ["..."], "missing": ["..."]}
        """
        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]

        let responseData = try await performRequest(payload: payload)
        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw NetworkError.cannotParseResponse
        }

        let decoded = try JSONDecoder().decode(DecodableRecipe.self, from: jsonData)
        return (decoded.required, decoded.missing)
    }

    func suggestRecipes(from inventory: [String]) async throws -> [RecommendedRecipe] {
        guard !inventory.isEmpty else { throw NetworkError.emptyInput }
        let prompt = """
        Based on the following ingredients: \(inventory.joined(separator: ", ")).
        Suggest 3 simple and delicious dishes I can make.
        Return the result in a strict JSON format like this:
        [
            { "name": "Dish Name 1", "description": "A short, appealing description of the dish." },
            { "name": "Dish Name 2", "description": "A short, appealing description of the dish." }
        ]
        """

        let payload: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["responseMimeType": "application/json"]
        ]

        let responseData = try await performRequest(payload: payload)
        guard let responseString = String(data: responseData, encoding: .utf8),
              let jsonString = extractJsonString(from: responseString),
              let jsonData = jsonString.data(using: .utf8) else {
            throw NetworkError.cannotParseResponse
        }

        return try JSONDecoder().decode([DecodableRecipeSuggestion].self, from: jsonData)
            .map { RecommendedRecipe(name: $0.name, description: $0.description) }
    }

    // MARK: - Private Helpers

    private func performRequest(payload: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else { throw NetworkError.missingAPIKey }
        guard let url = URL(string: "\(apiUrl)?key=\(apiKey)") else { throw NetworkError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw NetworkError.timeout
        } catch {
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.cannotParseResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.badServerResponse(statusCode: httpResponse.statusCode, body: body)
        }
        return data
    }

    private func extractJsonString(from text: String) -> String? {
        if let jsonRangeStart = text.range(of: "```json\n") {
            let startIndex = jsonRangeStart.upperBound
            if let jsonRangeEnd = text.range(of: "\n```", range: startIndex..<text.endIndex) {
                return String(text[startIndex..<jsonRangeEnd.lowerBound])
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Decodable DTOs

    private struct DecodableShelf: Codable { let shelfName: String; let items: [String] }
    private struct DecodableFoodExpiration: Codable { let name: String; let expiresInDays: Int }
    private struct DecodableRecipe: Codable { let required: [String]; let missing: [String] }
    private struct DecodableRecipeSuggestion: Codable { let name: String; let description: String }
}
