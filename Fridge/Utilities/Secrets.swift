import Foundation

enum Secrets {
    private static func getSecrets() -> [String: Any]? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let xml = FileManager.default.contents(atPath: path) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil)) as? [String: Any]
    }

    static var geminiApiKey: String? {
        guard let secrets = getSecrets(),
              let key = secrets["GeminiAPIKey"] as? String,
              !key.isEmpty else {
            return nil
        }
        return key
    }
}
