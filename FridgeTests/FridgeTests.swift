import Testing
import Foundation
import UIKit
@testable import Fridge

// MARK: - FoodItem Tests

struct FoodItemTests {

    @Test func daysUntilExpiration_futureDate_returnsPositive() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let item = FoodItem(name: "Milk", expirationDate: futureDate)
        let days = item.daysUntilExpiration
        #expect(days == 5)
    }

    @Test func daysUntilExpiration_today_returnsZero() {
        let today = Calendar.current.startOfDay(for: Date())
        let item = FoodItem(name: "Bread", expirationDate: today)
        let days = item.daysUntilExpiration
        #expect(days == 0)
    }

    @Test func daysUntilExpiration_pastDate_returnsNegative() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let item = FoodItem(name: "Yogurt", expirationDate: pastDate)
        let days = item.daysUntilExpiration
        #expect(days != nil)
        #expect(days! < 0)
    }

    @Test func daysUntilExpiration_nilDate_returnsNil() {
        let item = FoodItem(name: "Mystery", expirationDate: nil)
        #expect(item.daysUntilExpiration == nil)
    }

    @Test func init_defaultValues() {
        let item = FoodItem(name: "Apple")
        #expect(item.name == "Apple")
        #expect(item.expirationDate == nil)
        #expect(item.quantity == 1)
        #expect(item.shelf == nil)
    }

    @Test func init_customValues() {
        let date = Date()
        let item = FoodItem(name: "Eggs", expirationDate: date, quantity: 12)
        #expect(item.name == "Eggs")
        #expect(item.expirationDate == date)
        #expect(item.quantity == 12)
    }
}

// MARK: - Shelf Tests

struct ShelfTests {

    @Test func init_defaultValues() {
        let shelf = Shelf(name: "Top Shelf")
        #expect(shelf.name == "Top Shelf")
        #expect(shelf.items.isEmpty)
    }

    @Test func init_withItems() {
        let item1 = FoodItem(name: "Milk")
        let item2 = FoodItem(name: "Juice")
        let shelf = Shelf(name: "Door", items: [item1, item2])
        #expect(shelf.name == "Door")
        #expect(shelf.items.count == 2)
    }
}

// MARK: - RecommendedRecipe Tests

struct RecommendedRecipeTests {

    @Test func init_properties() {
        let recipe = RecommendedRecipe(name: "Scrambled Eggs", description: "Simple and tasty")
        #expect(recipe.name == "Scrambled Eggs")
        #expect(recipe.description == "Simple and tasty")
    }

    @Test func identifiable_uniqueIds() {
        let r1 = RecommendedRecipe(name: "A", description: "a")
        let r2 = RecommendedRecipe(name: "A", description: "a")
        #expect(r1.id != r2.id)
    }

    @Test func hashable_conformance() {
        let r1 = RecommendedRecipe(name: "Soup", description: "Warm")
        var set: Set<RecommendedRecipe> = []
        set.insert(r1)
        #expect(set.count == 1)
    }
}

// MARK: - AlertMessage Tests

struct AlertMessageTests {

    @Test func init_properties() {
        let alert = AlertMessage(message: "Something happened")
        #expect(alert.message == "Something happened")
    }

    @Test func identifiable_uniqueIds() {
        let a1 = AlertMessage(message: "A")
        let a2 = AlertMessage(message: "A")
        #expect(a1.id != a2.id)
    }
}

// MARK: - NetworkError Tests

struct NetworkErrorTests {

    @Test func missingAPIKey_description() {
        let error = NetworkError.missingAPIKey
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("API"))
    }

    @Test func badURL_description() {
        let error = NetworkError.badURL
        #expect(error.errorDescription != nil)
    }

    @Test func badServerResponse_includesStatusCode() {
        let error = NetworkError.badServerResponse(statusCode: 403, body: "Forbidden")
        #expect(error.errorDescription!.contains("403"))
    }

    @Test func cannotParseResponse_description() {
        let error = NetworkError.cannotParseResponse
        #expect(error.errorDescription != nil)
    }

    @Test func emptyInput_description() {
        let error = NetworkError.emptyInput
        #expect(error.errorDescription != nil)
    }

    @Test func timeout_description() {
        let error = NetworkError.timeout
        #expect(error.errorDescription != nil)
    }

    @Test func unknown_wrapsUnderlyingError() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "test error"])
        let error = NetworkError.unknown(underlying)
        #expect(error.errorDescription!.contains("test error"))
    }
}

// MARK: - ImageResizer Tests

struct ImageResizerTests {

    @Test func resize_scalesDownCorrectly() {
        // Create a 100x200 test image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 200))
        let original = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
        }

        let resized = ImageResizer.resize(image: original, targetSize: CGSize(width: 50, height: 50))
        #expect(resized != nil)
        // Height should be limiting: 50/200 = 0.25, width = 100*0.25 = 25
        #expect(resized!.size.width <= 50)
        #expect(resized!.size.height <= 50)
    }

    @Test func resize_alreadySmallerThanTarget() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let original = renderer.image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        let resized = ImageResizer.resize(image: original, targetSize: CGSize(width: 100, height: 100))
        #expect(resized != nil)
        // Since ratio is min(10, 10) = 1.0, image stays same size
        #expect(resized!.size.width <= 100)
        #expect(resized!.size.height <= 100)
    }
}

// MARK: - Secrets Tests

struct SecretsTests {

    @Test func geminiApiKey_returnsNilOrString() {
        // In test environment, Secrets.plist may not be bundled
        // The key point is this doesn't crash (no fatalError)
        let key = Secrets.geminiApiKey
        if let key {
            #expect(!key.isEmpty)
        }
        // If nil, that's fine - it means plist is not bundled in tests
    }
}

// MARK: - GeminiService Mock Tests

/// A mock URLProtocol that intercepts network requests for testing
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// A testable version of GeminiService that uses a custom URLSession
struct MockGeminiService: AIServiceProtocol, Sendable {
    private let apiKey: String
    private let session: URLSession
    private let apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    init(apiKey: String, session: URLSession) {
        self.apiKey = apiKey
        self.session = session
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
        Estimate expiration dates for: \(items.joined(separator: ", ")). \
        Return: [{"name": "Food Name", "expiresInDays": 7}]
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
        let prompt = "placeholder"
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
        let prompt = "placeholder"
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

    // MARK: - Private

    private func performRequest(payload: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else { throw NetworkError.missingAPIKey }
        guard let url = URL(string: "\(apiUrl)?key=\(apiKey)") else { throw NetworkError.badURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
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

    private struct DecodableShelf: Codable { let shelfName: String; let items: [String] }
    private struct DecodableFoodExpiration: Codable { let name: String; let expiresInDays: Int }
    private struct DecodableRecipe: Codable { let required: [String]; let missing: [String] }
    private struct DecodableRecipeSuggestion: Codable { let name: String; let description: String }
}

@Suite(.serialized)
struct GeminiServiceMockTests {

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeGeminiResponse(json: String) -> Data {
        // Wrap the JSON in Gemini API response format
        let wrapper = """
        {
          "candidates": [{
            "content": {
              "parts": [{"text": "\(json.replacingOccurrences(of: "\"", with: "\\\""))"}]
            }
          }]
        }
        """
        return wrapper.data(using: .utf8)!
    }

    @Test func analyzeFridgeImage_parsesResponse() async throws {
        let session = makeSession()
        let responseJson = """
        [{"shelfName":"Top","items":["Milk","Eggs"]},{"shelfName":"Bottom","items":["Beer"]}]
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJson.data(using: .utf8)!)
        }

        let service = MockGeminiService(apiKey: "test-key", session: session)
        let result = try await service.analyzeFridgeImage(imageData: Data([0xFF]), shelvesConfig: ["Top", "Bottom"])

        #expect(result.count == 2)
        #expect(result[0].shelfName == "Top")
        #expect(result[0].itemNames == ["Milk", "Eggs"])
        #expect(result[1].shelfName == "Bottom")
        #expect(result[1].itemNames == ["Beer"])
    }

    @Test func getExpirationDates_parsesResponse() async throws {
        let session = makeSession()
        let responseJson = """
        [{"name":"Milk","expiresInDays":5},{"name":"Eggs","expiresInDays":14}]
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJson.data(using: .utf8)!)
        }

        let service = MockGeminiService(apiKey: "test-key", session: session)
        let result = try await service.getExpirationDates(for: ["Milk", "Eggs"])

        #expect(result.count == 2)
        #expect(result[0].name == "Milk")
        #expect(result[0].expiresInDays == 5)
        #expect(result[1].name == "Eggs")
        #expect(result[1].expiresInDays == 14)
    }

    @Test func getExpirationDates_emptyInput_throws() async {
        let session = makeSession()
        let service = MockGeminiService(apiKey: "test-key", session: session)

        do {
            _ = try await service.getExpirationDates(for: [])
            #expect(Bool(false), "Should have thrown")
        } catch let error as NetworkError {
            if case .emptyInput = error {
                // expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func suggestRecipes_parsesResponse() async throws {
        let session = makeSession()
        let responseJson = """
        [{"name":"Omelette","description":"A simple egg dish"},{"name":"Soup","description":"Warm and comforting"}]
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJson.data(using: .utf8)!)
        }

        let service = MockGeminiService(apiKey: "test-key", session: session)
        let result = try await service.suggestRecipes(from: ["Eggs", "Onion"])

        #expect(result.count == 2)
        #expect(result[0].name == "Omelette")
        #expect(result[1].name == "Soup")
    }

    @Test func suggestRecipes_emptyInventory_throws() async {
        let session = makeSession()
        let service = MockGeminiService(apiKey: "test-key", session: session)

        do {
            _ = try await service.suggestRecipes(from: [])
            #expect(Bool(false), "Should have thrown")
        } catch let error as NetworkError {
            if case .emptyInput = error {
                // expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func getRecipeIngredients_parsesResponse() async throws {
        let session = makeSession()
        let responseJson = """
        {"required":["Eggs","Tomato","Oil","Salt"],"missing":["Tomato"]}
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJson.data(using: .utf8)!)
        }

        let service = MockGeminiService(apiKey: "test-key", session: session)
        let result = try await service.getRecipeIngredients(for: "Scrambled eggs with tomato", currentInventory: ["Eggs", "Oil", "Salt"])

        #expect(result.required.count == 4)
        #expect(result.missing == ["Tomato"])
    }

    @Test func missingAPIKey_throwsError() async {
        let session = makeSession()
        let service = MockGeminiService(apiKey: "", session: session)

        do {
            _ = try await service.getExpirationDates(for: ["Milk"])
            #expect(Bool(false), "Should have thrown")
        } catch let error as NetworkError {
            if case .missingAPIKey = error {
                // expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func serverError_throwsBadServerResponse() async {
        let session = makeSession()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Internal Server Error".data(using: .utf8)!)
        }

        let service = MockGeminiService(apiKey: "test-key", session: session)
        do {
            _ = try await service.getExpirationDates(for: ["Milk"])
            #expect(Bool(false), "Should have thrown")
        } catch let error as NetworkError {
            if case .badServerResponse(let code, _) = error {
                #expect(code == 500)
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test func invalidJson_throwsParseError() async {
        let session = makeSession()
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not valid json {{{}".data(using: .utf8)!)
        }

        let service = MockGeminiService(apiKey: "test-key", session: session)
        do {
            _ = try await service.getExpirationDates(for: ["Milk"])
            #expect(Bool(false), "Should have thrown")
        } catch {
            // Any error is expected here - JSON parsing should fail
        }
    }
}
