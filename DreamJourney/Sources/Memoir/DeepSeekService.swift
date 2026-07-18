import Foundation

/// Legacy compatibility facade. Provider calls must go through the backend so
/// the app bundle never owns a long-lived model credential.
final class DeepSeekService {
    static let shared = DeepSeekService()

    struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    enum DeepSeekError: LocalizedError {
        case apiKeyMissing
        case networkError(Error)
        case invalidResponse
        case emptyContent
        case rateLimited
        case directProviderDisabled

        var errorDescription: String? {
            switch self {
            case .apiKeyMissing, .directProviderDisabled:
                return "客户端大模型直连已停用，请使用后端代理能力"
            case .networkError:
                return "网络请求失败，请稍后再试"
            case .invalidResponse:
                return "服务端返回了无效的响应格式"
            case .emptyContent:
                return "大模型返回了空内容"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            }
        }
    }

    private init() {}

    func chat(
        messages: [ChatMessage],
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        completion: @escaping (Result<String, DeepSeekError>) -> Void
    ) {
        _ = (messages, temperature, maxTokens)
        completion(.failure(.directProviderDisabled))
    }

    func extractKnowledge(
        prompt: String,
        completion: @escaping (Result<KBExtractionResult, DeepSeekError>) -> Void
    ) {
        _ = prompt
        completion(.failure(.directProviderDisabled))
    }

    func analyzeImage(
        imageBase64: String,
        completion: @escaping (Result<KBImageAnalysisResult, DeepSeekError>) -> Void
    ) {
        _ = imageBase64
        completion(.failure(.directProviderDisabled))
    }
}
