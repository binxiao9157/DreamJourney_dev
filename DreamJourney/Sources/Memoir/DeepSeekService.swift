import Foundation
import Alamofire

// MARK: - DeepSeek API 服务

/// 封装 DeepSeek 大模型 API 调用（OpenAI 兼容接口）
/// 默认使用 DeepSeek 官方 API: https://api.deepseek.com/v1/chat/completions
/// 如需通过代理访问，在 Info.plist 中设置 DeepSeekAPIBaseURL
/// 模型: DeepSeek-V4-Flash
final class DeepSeekService {

    static let shared = DeepSeekService()

    // MARK: - Configuration

    /// 占位符，用于判断 Key 是否已配置
    private static let placeholderKey = "YOUR_DEEPSEEK_API_KEY"

    /// API Key — 优先从 Info.plist 读取，否则使用下方硬编码值
    private let apiKey: String

    /// API Base URL — 优先从 Info.plist 读取，否则使用 DeepSeek 官方 API
    private static let defaultBaseURL = "https://api.deepseek.com/v1/chat/completions"

    private let baseURL: String

    private let model = "DeepSeek-V4-Flash"
    private let timeoutInterval: TimeInterval = 60
    private let safetyGuardClient = DeepSeekSafetyGuarding.makeDefaultClient()

    // MARK: - Init

    private init() {
        // 优先从 Info.plist 读取 API Key
        if let key = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIKey") as? String,
           !key.isEmpty, key != Self.placeholderKey {
            self.apiKey = key
        } else {
            self.apiKey = Self.placeholderKey
        }

        // 优先从 Info.plist 读取 Base URL，否则使用 DeepSeek 官方 API
        if let url = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIBaseURL") as? String,
           !url.isEmpty {
            self.baseURL = url
        } else {
            self.baseURL = Self.defaultBaseURL
        }
    }

    // MARK: - Request / Response Models

    struct ChatMessage: Encodable {
        let role: String      // "system" / "user" / "assistant"
        let content: String
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message

            struct Message: Decodable {
                let content: String
            }
        }
    }

    // MARK: - Error

    enum DeepSeekError: LocalizedError {
        case apiKeyMissing
        case networkError(Error)
        case invalidResponse
        case emptyContent
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .apiKeyMissing:
                return "API Key 未配置，请在 DeepSeekService 中设置"
            case .networkError(let error):
                return "网络请求失败: \(error.localizedDescription)"
            case .invalidResponse:
                return "服务端返回了无效的响应格式"
            case .emptyContent:
                return "大模型返回了空内容"
            case .rateLimited:
                return "请求过于频繁，请稍后再试"
            }
        }
    }

    // MARK: - Public API

    /// 调用 DeepSeek Chat API
    /// - Parameters:
    ///   - messages: 对话消息列表（包含 system prompt + 用户上下文）
    ///   - temperature: 创意度，0.0~1.0，默认 0.7
    ///   - maxTokens: 最大输出 token 数，默认 2048
    ///   - completion: 回调，成功返回 AI 回复文本，失败返回错误
    func chat(
        messages: [ChatMessage],
        temperature: Double = 0.7,
        maxTokens: Int = 2048,
        completion: @escaping (Result<String, DeepSeekError>) -> Void
    ) {
        // 检查 API Key 是否已配置
        guard apiKey != Self.placeholderKey else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let guardText = messages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        guard canSendToLLM(text: guardText, surface: .memoir, stage: .userInputPreLLM) else {
            completion(.failure(.invalidResponse))
            return
        }

        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens
        )

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
        ]

        AF.request(
            baseURL,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        )
        .validate(statusCode: 200..<300)
        .responseData(queue: .global(qos: .userInitiated)) { [weak self] response in
            self?.handleResponse(response, completion: completion)
        }
    }

    // MARK: - Knowledge Extraction (KBLite)

    /// 调用 DeepSeek 做结构化知识提取
    func extractKnowledge(
        prompt: String,
        completion: @escaping (Result<KBExtractionResult, DeepSeekError>) -> Void
    ) {
        guard apiKey != Self.placeholderKey else {
            completion(.failure(.apiKeyMissing))
            return
        }

        guard canSendToLLM(text: prompt, surface: .knowledge, stage: .userInputPreLLM) else {
            completion(.failure(.invalidResponse))
            return
        }

        let messages: [ChatMessage] = [
            ChatMessage(role: "system", content: "你是一个精确的 JSON 提取器。只输出 JSON，不输出任何其他内容。"),
            ChatMessage(role: "user", content: prompt)
        ]

        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.1,
            max_tokens: 2048
        )

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
        ]

        AF.request(
            baseURL,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        )
        .validate(statusCode: 200..<300)
        .responseData(queue: .global(qos: .userInitiated)) { [weak self] response in
            self?.handleExtractionResponse(response, completion: completion)
        }
    }

    /// 解析知识提取响应
    private func handleExtractionResponse(
        _ response: AFDataResponse<Data>,
        completion: @escaping (Result<KBExtractionResult, DeepSeekError>) -> Void
    ) {
        switch response.result {
        case .success(let data):
            guard let chatResponse = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  var content = chatResponse.choices.first?.message.content,
                  !content.isEmpty else {
                completion(.failure(.emptyContent))
                return
            }

            content = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("[DeepSeekService] 🧠 知识提取输出: \(content.prefix(300))")

            guard let jsonData = content.data(using: .utf8) else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                let result = try JSONDecoder().decode(KBExtractionResult.self, from: jsonData)
                completion(.success(result))
            } catch {
                print("[DeepSeekService] ⚠️ JSON 解析失败: \(error)，尝试提取子串...")
                if let extractedJSON = extractJSONSubstring(from: content),
                   let extractedData = extractedJSON.data(using: .utf8) {
                    do {
                        let result = try JSONDecoder().decode(KBExtractionResult.self, from: extractedData)
                        completion(.success(result))
                        return
                    } catch {
                        print("[DeepSeekService] ⚠️ 子串提取也失败: \(error)")
                    }
                }
                completion(.failure(.invalidResponse))
            }

        case .failure(let error):
            if let data = response.data, let raw = String(data: data, encoding: .utf8) {
                print("[DeepSeekService] ❌ 提取失败: \(raw.prefix(500))")
            }
            completion(.failure(.networkError(error)))
        }
    }

    /// 从字符串中提取第一个有效 JSON 对象
    private func extractJSONSubstring(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }
        return jsonStr
    }

    // MARK: - Image Analysis (KBLite)

    // analyzeImage 使用 URLRequest 而非 Alamofire 参数编码，
    // 因为 Vision API 的 content 字段需要混合 text + image_url 的数组格式，
    // Alamofire 的 JSONParameterEncoder 无法直接表达 [String: Any] 中嵌套异构数组。

    /// 调用 DeepSeek Vision API 分析图片
    func analyzeImage(
        imageBase64: String,
        completion: @escaping (Result<KBImageAnalysisResult, DeepSeekError>) -> Void
    ) {
        guard apiKey != Self.placeholderKey else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let analysisPrompt = """
        描述这张照片的内容。关注：1. 场景（在哪里、什么场合）2. 人物（数量、年龄、推测关系）3. 活动（在做什么）4. 情绪氛围 5. 年代特征。
        请输出严格JSON：{"description":"...","detectedPeople":["..."],"scene":"...","occasion":"...","mood":"...","estimatedDecade":1970}
        """

        guard canSendToLLM(text: analysisPrompt, surface: .photoAnalysis, stage: .imagePreAnalysis) else {
            completion(.failure(.invalidResponse))
            return
        }

        let messages: [[String: Any]] = [
            ["role": "system", "content": "你是老照片分析专家。输出严格JSON，不要其他文字。"],
            ["role": "user", "content": [
                ["type": "text", "text": analysisPrompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
            ]]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1024
        ]

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)",
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(.invalidResponse))
            return
        }

        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = headers.dictionary
        urlRequest.httpBody = bodyData
        urlRequest.timeoutInterval = timeoutInterval

        AF.request(urlRequest)
            .validate(statusCode: 200..<300)
            .responseData(queue: .global(qos: .userInitiated)) { [weak self] response in
                guard let self = self else { return }
                switch response.result {
                case .success(let data):
                    guard let chatResponse = try? JSONDecoder().decode(ChatResponse.self, from: data),
                          var content = chatResponse.choices.first?.message.content,
                          !content.isEmpty else {
                        completion(.failure(.emptyContent))
                        return
                    }
                    content = content
                        .replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    if let jsonData = content.data(using: .utf8),
                       let result = try? JSONDecoder().decode(KBImageAnalysisResult.self, from: jsonData) {
                        completion(.success(result))
                    } else if let extractedJSON = self.extractJSONSubstring(from: content),
                              let extractedData = extractedJSON.data(using: .utf8),
                              let result = try? JSONDecoder().decode(KBImageAnalysisResult.self, from: extractedData) {
                        completion(.success(result))
                    } else {
                        let fallback = KBImageAnalysisResult(description: content)
                        completion(.success(fallback))
                    }
                case .failure(let error):
                    completion(.failure(.networkError(error)))
                }
            }
    }

    // MARK: - Response Handling

    private func handleResponse(
        _ response: AFDataResponse<Data>,
        completion: @escaping (Result<String, DeepSeekError>) -> Void
    ) {
        // 打印请求详情用于调试
        print("[DeepSeekService] 请求URL: \(response.request?.url?.absoluteString ?? "nil")")
        print("[DeepSeekService] HTTP状态码: \(response.response?.statusCode ?? -1)")
        
        switch response.result {
        case .success(let data):
            // 检查 HTTP 状态码
            if let statusCode = response.response?.statusCode, statusCode == 429 {
                completion(.failure(.rateLimited))
                return
            }
            
            // 非2xx状态码也打印原始响应
            if let statusCode = response.response?.statusCode, statusCode >= 300 {
                if let rawString = String(data: data, encoding: .utf8) {
                    print("[DeepSeekService] ❌ HTTP \(statusCode) 响应体: \(rawString.prefix(1000))")
                }
                completion(.failure(.invalidResponse))
                return
            }

            // 解析响应
            guard let chatResponse = try? JSONDecoder().decode(ChatResponse.self, from: data),
                  let content = chatResponse.choices.first?.message.content,
                  !content.isEmpty else {

                // 尝试打印原始响应用于调试
                if let rawString = String(data: data, encoding: .utf8) {
                    print("[DeepSeekService] 响应解析失败，原始内容: \(rawString.prefix(500))")
                }
                completion(.failure(.invalidResponse))
                return
            }

            completion(.success(content))

        case .failure(let error):
            // Alamofire validate() 失败时，仍然可能有响应体（如403的错误信息）
            if let data = response.data, let rawString = String(data: data, encoding: .utf8) {
                print("[DeepSeekService] ❌ 请求失败，HTTP \(response.response?.statusCode ?? -1)，响应体: \(rawString.prefix(1000))")
            } else {
                print("[DeepSeekService] 网络请求失败: \(error.localizedDescription)")
            }
            completion(.failure(.networkError(error)))
        }
    }

    private func canSendToLLM(
        text: String,
        surface: SafetyGuardSurface,
        stage: SafetyGuardStage
    ) -> Bool {
        let decision = DeepSeekSafetyGuarding.guardDecision(
            text: text,
            surface: surface,
            stage: stage,
            target: .deepseek,
            guardClient: safetyGuardClient
        )
        return decision.canSendToLLM && (decision.action == .allow || decision.action == .allowWithCare)
    }
}
