import Foundation

enum NetworkError: LocalizedError {
    case missingAPIKey
    case badURL
    case badServerResponse(statusCode: Int, body: String)
    case cannotParseResponse
    case emptyInput
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API密钥缺失，请在Secrets.plist中配置GeminiAPIKey。"
        case .badURL:
            return "请求地址无效。"
        case .badServerResponse(let statusCode, let body):
            return "服务器返回错误 (\(statusCode)): \(body)"
        case .cannotParseResponse:
            return "无法解析AI返回的数据。"
        case .emptyInput:
            return "没有可供分析的数据。"
        case .timeout:
            return "请求超时，请检查网络连接后重试。"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
