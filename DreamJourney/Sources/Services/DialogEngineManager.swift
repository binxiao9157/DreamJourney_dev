import Foundation
import CryptoKit
import zlib

// S2: main-queue state only; does not own audio, capture or memory writes.
struct LiveContextUpdateState {
    struct Request: Equatable {
        let id: UUID
        let operation: UUID
        let generation: Int
        let ticketID: String
        let sequence: Int
        let previousHash: String
        let query: String
        let deadline: TimeInterval
    }
    private(set) var operation: UUID?
    private(set) var ticketID: String?
    private(set) var appliedHash = ""
    private(set) var sequence = 1
    private(set) var generation = 0
    private(set) var disabled = false
    private(set) var fetching: Request?
    private(set) var awaitingACK: (request: Request, hash: String, deadline: TimeInterval)?
    private var query: String?
    private var attemptedGeneration = -1
    private var requestCount = 0

    mutating func begin(operation: UUID, ticketID: String?, hash: String?) {
        self = Self()
        self.operation = operation
        self.ticketID = ticketID
        self.appliedHash = hash ?? ""
        self.disabled = ticketID == nil || hash == nil
    }

    mutating func end() { self = Self(); disabled = true }

    mutating func observeASR(_ text: String, isFinal: Bool) {
        guard !disabled, operation != nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFinal, query == trimmed { return }
        generation += 1
        fetching = nil
        query = isFinal && trimmed.count <= 512 ? trimmed : nil
    }

    mutating func afterPlaybackDrained(now: TimeInterval) -> Request? {
        guard !disabled, fetching == nil, awaitingACK == nil,
              let operation, let ticketID, let query,
              attemptedGeneration != generation, requestCount < 128 else { return nil }
        let request = Request(id: UUID(), operation: operation, generation: generation,
                              ticketID: ticketID, sequence: sequence, previousHash: appliedHash,
                              query: query, deadline: now + 0.5)
        fetching = request
        attemptedGeneration = generation
        requestCount += 1
        return request
    }

    mutating func prepareSend(_ request: Request, hash: String, now: TimeInterval) -> Bool {
        guard !disabled, fetching == request, operation == request.operation,
              generation == request.generation, now < request.deadline else { return false }
        fetching = nil
        awaitingACK = (request, hash, now + 1)
        return true
    }

    mutating func readFailed(_ request: Request) {
        if fetching == request { fetching = nil }
    }

    mutating func acknowledge(now: TimeInterval) -> Bool {
        guard !disabled, let pending = awaitingACK else { return false }
        guard now < pending.deadline else { disable(); return false }
        appliedHash = pending.hash
        sequence += 1
        awaitingACK = nil
        return true
    }

    mutating func expireACK(requestID: UUID, now: TimeInterval) {
        if let pending = awaitingACK, pending.request.id == requestID, now >= pending.deadline { disable() }
    }

    mutating func disable() {
        disabled = true
        fetching = nil
        awaitingACK = nil
        query = nil
    }
}

// Presentation metering only: never persists PCM, controls audio, or completes a turn.
enum DialogOrbAudioChannel: Int { case input, output }
struct DialogOrbAudioSample {
    let channel: DialogOrbAudioChannel
    let level: Float
    let capturedAt: TimeInterval
    let generation: UUID
    let operation: UUID
    let nonce: UUID
}

enum DialogOrbPCM {
    static func level(_ data: Data) -> Float {
        guard data.count >= 2, data.count.isMultiple(of: 2) else { return 0 }
        return data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            let count = bytes.count / 2
            let step = max(1, (count + 1023) / 1024)
            var energy = 0.0
            var measured = 0
            for index in stride(from: 0, to: count, by: step) {
                let bits = UInt16(bytes[index * 2]) | (UInt16(bytes[index * 2 + 1]) << 8)
                let sample = Double(Int16(bitPattern: bits)) / 32768
                energy += sample * sample; measured += 1
            }
            let rms = sqrt(energy / Double(max(1, measured)))
            guard rms > 0 else { return 0 }
            return Float(min(1, max(0, (20 * log10(rms) + 50) / 38)))
        }
    }
}

/// At most one outstanding UI message per channel. Main-thread congestion cannot
/// create a PCM backlog. The generation/operation pair is frozen at SDK ingress.
final class DialogOrbAudioRelay {
    private let lock = NSLock()
    private var generation: UUID?
    private var operation: UUID?
    private var last = [TimeInterval](repeating: -.infinity, count: 2)
    private var pending: [UUID?] = [nil, nil]
    func activate(generation: UUID, operation: UUID) {
        lock.lock(); defer { lock.unlock() }
        self.generation = generation; self.operation = operation
        last = [-.infinity, -.infinity]; pending = [nil, nil]
    }
    func close(operation expected: UUID? = nil) {
        lock.lock(); defer { lock.unlock() }
        guard expected == nil || operation == expected else { return }
        generation = nil; operation = nil; pending = [nil, nil]
    }
    func sample(channel: DialogOrbAudioChannel, pcm: Data, generation: UUID,
                now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> DialogOrbAudioSample? {
        lock.lock(); defer { lock.unlock() }
        let index = channel.rawValue
        guard self.generation == generation, let operation,
              pending[index] == nil, now - last[index] >= 1.0 / 30 else { return nil }
        last[index] = now
        let nonce = UUID(); pending[index] = nonce
        return DialogOrbAudioSample(channel: channel, level: DialogOrbPCM.level(pcm),
            capturedAt: now, generation: generation, operation: operation, nonce: nonce)
    }
    func complete(_ sample: DialogOrbAudioSample) {
        lock.lock(); defer { lock.unlock() }
        if pending[sample.channel.rawValue] == sample.nonce { pending[sample.channel.rawValue] = nil }
    }
}

struct EchoOrbEnvelope {
    private(set) var value: Float = 0
    private var target: Float = 0
    private var sampleTime: TimeInterval = -.infinity
    private var frameTime: TimeInterval?
    mutating func receive(_ level: Float, at time: TimeInterval) {
        guard level.isFinite, time.isFinite, time >= sampleTime else { return }
        target = max(0, min(1, level)); sampleTime = time
    }
    mutating func advance(at time: TimeInterval) -> Float {
        let delta = min(0.1, max(0, time - (frameTime ?? time - 1.0 / 30)))
        frameTime = time
        let wanted: Float = time - sampleTime <= 0.18 ? target : 0
        let tau = wanted > value ? 0.06 : 0.20
        value += (wanted - value) * Float(1 - exp(-delta / tau))
        if value < 0.001 { value = 0 }
        return value
    }
    mutating func reset() { self = Self() }
}


enum DialogProviderLiveStartConfigError: Error {
    case missingRoleText
    case invalidDialogShape
    case invalidStartConfig
}

enum DialogProviderLiveStartConfigBuilder {
    static let adapterVersion = "volc-speechengine-canonical-start-session-v3"
    static let endpointingMilliseconds = 1_500
    static let speechRate = -20
    static let loudnessRate = 10

    static func makeCanonicalStartConfig(
        systemRole: String,
        speakingStyle: String,
        model: String,
        ttsSpeaker: String?,
        hotwords: [String]
    ) -> [String: Any] {
        var asr: [String: Any] = [
            "audio_info": [
                "format": "pcm",
                "sample_rate": 16_000,
                "channel": 1,
            ],
            "extra": [
                "end_smooth_window_ms": endpointingMilliseconds,
                "enable_custom_vad": true,
            ],
        ]
        if !hotwords.isEmpty {
            asr["hot_words"] = hotwords
        }
        var result: [String: Any] = [
            "asr": asr,
            "dialog": [
                "bot_name": "寻梦环游",
                "system_role": systemRole,
                "speaking_style": speakingStyle,
                "extra": ["model": model],
            ],
        ]
        if let ttsSpeaker {
            result["tts"] = [
                "speaker": ttsSpeaker,
                "audio_config": [
                    "speech_rate": speechRate,
                    "loudness_rate": loudnessRate,
                ],
            ]
        }
        return result
    }

    static func applying(
        providerRoleText: String,
        to dialogConfig: [String: Any]
    ) throws -> [String: Any] {
        let normalized = providerRoleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw DialogProviderLiveStartConfigError.missingRoleText
        }
        guard var dialog = dialogConfig["dialog"] as? [String: Any],
              !containsLegacyNestedSections(dialog) else {
            throw DialogProviderLiveStartConfigError.invalidDialogShape
        }
        dialog["system_role"] = providerRoleText
        var result = dialogConfig
        result["dialog"] = dialog
        return result
    }

    static func submittedRoleText(in startConfig: [String: Any]) -> String? {
        guard let dialog = startConfig["dialog"] as? [String: Any],
              !containsLegacyNestedSections(dialog),
              systemRoleOccurrences(in: startConfig) == 1,
              let role = dialog["system_role"] as? String,
              !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return role
    }

    static func encodedStartConfig(
        _ startConfig: [String: Any],
        expectedProviderRoleText: String? = nil
    ) throws -> String {
        guard let dialog = startConfig["dialog"] as? [String: Any],
              !containsLegacyNestedSections(dialog),
              nonEmptyString(dialog["bot_name"]) != nil,
              submittedRoleText(in: startConfig) != nil,
              nonEmptyString(dialog["speaking_style"]) != nil,
              let extra = dialog["extra"] as? [String: Any],
              nonEmptyString(extra["model"]) != nil,
              startConfig["asr"] is [String: Any] else {
            throw DialogProviderLiveStartConfigError.invalidDialogShape
        }
        if let tts = startConfig["tts"] {
            guard let tts = tts as? [String: Any],
                  nonEmptyString(tts["speaker"]) != nil,
                  tts["audio_config"] is [String: Any] else {
                throw DialogProviderLiveStartConfigError.invalidDialogShape
            }
        }
        if let expectedProviderRoleText,
           submittedRoleText(in: startConfig) != expectedProviderRoleText {
            throw DialogProviderLiveStartConfigError.invalidDialogShape
        }
        guard JSONSerialization.isValidJSONObject(startConfig),
              let data = try? JSONSerialization.data(withJSONObject: startConfig),
              let encoded = String(data: data, encoding: .utf8) else {
            throw DialogProviderLiveStartConfigError.invalidStartConfig
        }
        return encoded
    }

    private static func containsLegacyNestedSections(_ dialog: [String: Any]) -> Bool {
        dialog["dialog"] != nil || dialog["asr"] != nil || dialog["tts"] != nil
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    private static func systemRoleOccurrences(in value: Any) -> Int {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: 0) { count, element in
                if element.key == "system_role" {
                    count += 1
                } else {
                    count += systemRoleOccurrences(in: element.value)
                }
            }
        }
        if let array = value as? [Any] {
            return array.reduce(0) { $0 + systemRoleOccurrences(in: $1) }
        }
        return 0
    }
}

enum DialogChatRAGTextPayloadError: Error {
    case emptyContent
    case payloadTooLarge
    case encodingFailed
}

enum DialogChatRAGTextPayloadEncoder {
    static let maximumCharacters = 4_096

    static func encode(
        content: String,
        title: String = "已确认正式事实"
    ) throws -> String {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw DialogChatRAGTextPayloadError.emptyContent
        }
        let entries: [[String: String]] = [[
            "title": title,
            "content": content,
        ]]
        guard let entriesData = try? JSONSerialization.data(withJSONObject: entries),
              let entriesJSON = String(data: entriesData, encoding: .utf8),
              let payloadData = try? JSONSerialization.data(
                withJSONObject: ["external_rag": entriesJSON]
              ),
              let payload = String(data: payloadData, encoding: .utf8) else {
            throw DialogChatRAGTextPayloadError.encodingFailed
        }
        guard payload.count <= maximumCharacters else {
            throw DialogChatRAGTextPayloadError.payloadTooLarge
        }
        return payload
    }
}

#if DEBUG
enum DialogT06DiagnosticMode {
    static let launchArgument = "-DreamJourneyT06SDKCapture"
    static let expectedRolePath = "dialog.system_role"
    static let syntheticProviderRoleText = """
        T06 synthetic formal memory. Only use these synthetic facts.
        Education: graduated from Synthetic University.
        Occupation: synthetic software engineer.
        Food preference: synthetic tomato noodles.
        """

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    static var providerContextHash: String {
        DialogT06SDKFrameInspector.sha256(syntheticProviderRoleText)
    }
}

struct DialogT06SDKFrameObservation: Equatable {
    let event: Int
    let fieldPath: String
    let roleByteCount: Int
    let roleHash: String
    let providerContextHash: String
    let modelFieldPresent: Bool
    let hasLegacyDialogWrapper: Bool
    let roleMatchesExpected: Bool
    let hashMatchesExpected: Bool
    let fieldPathMatchesExpected: Bool

    var contractMatches: Bool {
        event == 100
            && roleMatchesExpected
            && hashMatchesExpected
            && fieldPathMatchesExpected
            && modelFieldPresent
            && !hasLegacyDialogWrapper
    }
}

enum DialogT06SDKFrameInspector {
    static let startSessionEvent = 100
    static let maximumCompressedPayloadBytes = 128 * 1_024
    static let maximumDecodedPayloadBytes = 512 * 1_024

    static func inspect(
        frame: Data,
        expectedRoleText: String,
        expectedProviderContextHash: String,
        expectedFieldPath: String
    ) -> DialogT06SDKFrameObservation? {
        guard let envelope = parseClientEventFrame(frame),
              envelope.event == startSessionEvent,
              let object = try? JSONSerialization.jsonObject(with: envelope.payload),
              let root = object as? [String: Any] else {
            return nil
        }
        let roles = findSystemRoles(in: root)
        guard roles.count == 1, let role = roles.first else { return nil }
        let dialog = root["dialog"] as? [String: Any]
        let extra = dialog?["extra"] as? [String: Any]
        let roleHash = sha256(role.value)
        return DialogT06SDKFrameObservation(
            event: envelope.event,
            fieldPath: role.path,
            roleByteCount: role.value.utf8.count,
            roleHash: roleHash,
            providerContextHash: expectedProviderContextHash,
            modelFieldPresent: extra?["model"] is String,
            hasLegacyDialogWrapper: dialog?["dialog"] != nil
                || dialog?["asr"] != nil
                || dialog?["tts"] != nil,
            roleMatchesExpected: role.value == expectedRoleText,
            hashMatchesExpected: roleHash == expectedProviderContextHash,
            fieldPathMatchesExpected: role.path == expectedFieldPath
        )
    }

    static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "sha256:" + digest
    }

    static func gzipForTesting(_ data: Data) -> Data? {
        var stream = z_stream()
        guard deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            15 + 16,
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        ) == Z_OK else {
            return nil
        }
        defer { deflateEnd(&stream) }

        return data.withUnsafeBytes { inputBuffer -> Data? in
            guard let input = inputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return nil
            }
            stream.next_in = UnsafeMutablePointer(mutating: input)
            stream.avail_in = uInt(data.count)
            var output = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            let bufferCapacity = buffer.count

            repeat {
                let status = buffer.withUnsafeMutableBytes { outputBuffer -> Int32 in
                    stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferCapacity)
                    return deflate(&stream, Z_FINISH)
                }
                guard status == Z_OK || status == Z_STREAM_END else { return nil }
                output.append(
                    contentsOf: buffer.prefix(bufferCapacity - Int(stream.avail_out))
                )
                if status == Z_STREAM_END {
                    return output
                }
            } while output.count <= maximumCompressedPayloadBytes
            return nil
        }
    }

    private struct ClientEventEnvelope {
        let event: Int
        let payload: Data
    }

    private static func parseClientEventFrame(_ frame: Data) -> ClientEventEnvelope? {
        let bytes = [UInt8](frame)
        guard bytes.count >= 12,
              bytes[0] >> 4 == 1,
              bytes[1] >> 4 == 1,
              bytes[2] >> 4 == 1 else {
            return nil
        }
        let headerBytes = Int(bytes[0] & 0x0F) * 4
        guard headerBytes >= 4, headerBytes <= bytes.count - 8 else { return nil }

        let flags = bytes[1] & 0x0F
        guard flags & 0x04 == 0x04 else { return nil }
        var offset = headerBytes
        switch flags & 0x03 {
        case 0x01, 0x03:
            guard readUInt32(bytes, at: offset) != nil else { return nil }
            offset += 4
        case 0x00, 0x02:
            break
        default:
            return nil
        }

        guard let event = readUInt32(bytes, at: offset) else { return nil }
        offset += 4

        if event == startSessionEvent {
            guard let sessionIDSize = readUInt32(bytes, at: offset),
                  sessionIDSize > 0,
                  sessionIDSize <= 1_024 else {
                return nil
            }
            offset += 4
            guard offset + sessionIDSize <= bytes.count else { return nil }
            offset += sessionIDSize
        }

        let declaredSize = readUInt32(bytes, at: offset)
        guard let declaredSize,
              declaredSize > 0,
              declaredSize <= maximumCompressedPayloadBytes else {
            return nil
        }
        let payloadOffset = offset + 4
        guard payloadOffset + declaredSize == bytes.count else { return nil }
        let compressedPayload = Data(bytes[payloadOffset..<bytes.count])
        let compression = bytes[2] & 0x0F
        let payload: Data
        switch compression {
        case 0:
            payload = compressedPayload
        case 1:
            guard let uncompressed = gunzip(
                compressedPayload,
                maximumOutputBytes: maximumDecodedPayloadBytes
            ) else { return nil }
            payload = uncompressed
        default:
            return nil
        }
        guard payload.count <= maximumDecodedPayloadBytes else { return nil }
        return ClientEventEnvelope(event: event, payload: payload)
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> Int? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return Int(bytes[offset]) << 24
            | Int(bytes[offset + 1]) << 16
            | Int(bytes[offset + 2]) << 8
            | Int(bytes[offset + 3])
    }

    private static func findSystemRoles(
        in value: Any,
        path: String = ""
    ) -> [(path: String, value: String)] {
        if let dictionary = value as? [String: Any] {
            var results: [(String, String)] = []
            for key in dictionary.keys.sorted() {
                let childPath = path.isEmpty ? key : path + "." + key
                if key == "system_role", let role = dictionary[key] as? String {
                    results.append((childPath, role))
                } else if let child = dictionary[key] {
                    results.append(contentsOf: findSystemRoles(in: child, path: childPath))
                }
            }
            return results
        }
        if let array = value as? [Any] {
            return array.enumerated().flatMap { index, child in
                findSystemRoles(in: child, path: path + "[\(index)]")
            }
        }
        return []
    }

    private static func gunzip(
        _ data: Data,
        maximumOutputBytes: Int
    ) -> Data? {
        guard data.count >= 2,
              data[data.startIndex] == 0x1F,
              data[data.index(after: data.startIndex)] == 0x8B else {
            return nil
        }

        var stream = z_stream()
        guard inflateInit2_(
            &stream,
            15 + 32,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        ) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        return data.withUnsafeBytes { inputBuffer -> Data? in
            guard let input = inputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                return nil
            }
            stream.next_in = UnsafeMutablePointer(mutating: input)
            stream.avail_in = uInt(data.count)
            var output = Data()
            var buffer = [UInt8](repeating: 0, count: 4_096)
            let bufferCapacity = buffer.count

            while true {
                let status = buffer.withUnsafeMutableBytes { outputBuffer -> Int32 in
                    stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferCapacity)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                let produced = bufferCapacity - Int(stream.avail_out)
                if produced > 0 {
                    guard output.count + produced <= maximumOutputBytes else {
                        return nil
                    }
                    output.append(contentsOf: buffer.prefix(produced))
                }
                if status == Z_STREAM_END {
                    return output
                }
                guard status == Z_OK, stream.avail_in > 0 || produced > 0 else {
                    return nil
                }
            }
        }
    }
}
#endif

#if DEBUG || UI_QA_SIMULATOR
struct DialogPromptDebugSnapshot {
    let prompt: String
    let containsArchiveContext: Bool
    let recordedAt: Date
}

enum DialogPromptDebugRecorder {
    private(set) static var lastSnapshot: DialogPromptDebugSnapshot?

    static func record(prompt: String, recordedAt: Date = Date()) {
        lastSnapshot = DialogPromptDebugSnapshot(
            prompt: prompt,
            containsArchiveContext: prompt.contains("【记忆档案馆素材线索】"),
            recordedAt: recordedAt
        )
    }

    static func reset() {
        lastSnapshot = nil
    }
}
#endif

private func shouldExposePersonalContext(for context: DigitalHumanContext) -> Bool {
    context.mode != .silent
}

private func shouldExposeArchiveContext(for context: DigitalHumanContext) -> Bool {
    shouldExposePersonalContext(for: context)
}

enum EchoResponseStylePolicy {
    static func promptSection(context: DigitalHumanContext) -> String {
        let displayName = String(
            context.resolvedDisplayName
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")
                .prefix(40)
        )
        let identityPolicy: String
        let memoryGapResponse: String
        if context.isSelfAssistant {
            identityPolicy = """
            - 当前身份是用户自己的 AI 助手。涉及用户本人事实时使用“你”或“你的”，绝不能以“我”冒充用户。
            """
            memoryGapResponse = "关于这件事，我目前还了解得不够清楚。愿意从你最先想到的部分聊起吗？"
        } else {
            identityPolicy = """
            - 当前身份是“\(displayName)”的 AI 数字分身。回答该家人的已确认事实时，使用第一人称“我”做自然、口语化的转述。
            - 第一人称只是 AI 数字分身的表达方式，不代表你是真人本人；不得声称具有真人的意识、当下感受或亲历。
            """
            memoryGapResponse = "这件事在我现有的记忆里还不够清楚。"
        }

        return """


        【回答身份与事实表达】
        \(identityPolicy)
        - 每轮提供的已授权正式记忆是人物事实的唯一依据。人物、时间、地点、关系、职业、事件、观点、情绪、数字和因果不得增删、替换、推断或美化。
        - 正式记忆原文保持客观不变；你只可以在本轮回答的表达层调整语序和口语说法，不得把润色后的回答反向当作新事实。
        - 回答要像自然聊天，先直接回答问题。避免逐字照搬记忆，也不要让普通回答总以“根据正式记忆”或“记录显示”开头。
        - 只有用户明显愿意展开、话题适合继续，而且确有一个自然延伸点时，才可以加一句简短追问；不要每次都追问。
        - 用户只是在核对明确事实、要求简短答案或准备结束话题时，不要追加推动对话。需要追问时每轮只问一个问题。
        - 不得为了显得温柔而补写记忆中没有的感受、评价、原因或经历。回答通常一到三句，温和、自然、克制。
        - 资料不足时直接说：“\(memoryGapResponse)”不要用常识补写人物经历。
        - 本节关于身份、事实边界和是否追问的规则，优先于前文的通用访谈引导。
        """
    }
}

/// Live starts from the authoritative server memory on each user turn. Its
/// greeting must therefore stay neutral instead of claiming that a lossy local
/// transcript summary is a confirmed memory.
enum LiveSessionGreetingPolicy {
    static let greetings = [
        "您好呀，我是寻梦环游。今天想从哪件事开始聊？",
        "您好，我在这里听着。今天想聊聊什么？",
        "又见面啦。您慢慢说，今天想先从哪里讲起？",
        "您好呀，今天有没有什么想和我说的？",
        "您好，我准备好了。今天想聊一段怎样的回忆？",
    ]

    static func makeGreeting() -> String {
        greetings.randomElement() ?? "您好，我在这里听着。今天想聊聊什么？"
    }
}

private func buildDigitalHumanModePolicy(context: DigitalHumanContext) -> String {
    let responseStylePolicy = EchoResponseStylePolicy.promptSection(context: context)
    let modePolicy: String
    switch context.mode {
    case .sunlight:
        modePolicy = """


        【当前回响边界】
        - 当前对象用于日常陪伴与记忆整理，语气保持自然、温和、不过度心理化。
        - 不要在对话中说出内部状态名称，也不要解释系统如何分类对象。
        """
    case .star:
        modePolicy = """


        【关怀回应边界】
        - 当前对象需要更谨慎的陪伴式回应；可以温和关注情绪、睡眠、孤独感和风险信号。
        - 这不是医疗诊断，也不能替代心理医生、精神科医生或急救服务。
        - 遇到强烈痛苦、危险表达或自伤风险时，先共情、降低追问强度，并建议联系身边家人或当地紧急服务。
        - 不要在对话中说出内部状态名称，也不要解释系统如何分类对象。
        """
    case .silent:
        modePolicy = """


        【非公开展示边界】
        - 当前对象处于不公开展示边界，只保留最克制的陪伴回应。
        - 不主动引用档案素材、亲属线索或可能暴露隐私的历史内容。
        - 不要在对话中说出内部状态名称，也不要解释系统如何分类对象。
        """
    }
    return responseStylePolicy + modePolicy
}

enum VoiceSDKReadinessState: String {
    case mockASRTTS
    case backendTokenFallback
    case providerCredentialBlocked
    case productionSDKNeedsTrueDeviceQA
    case productionSDKVerified
}

struct VoiceSDKReadinessSummary {
    let state: VoiceSDKReadinessState
    let title: String
    let detail: String
    let allowsProductionClosureClaim: Bool

    static func current(
        backendRuntimeConfigured: Bool,
        backendRuntimeTokenApplied: Bool,
        localConfigReady: Bool,
        productionVoiceSDKQualityVerified: Bool,
        isUIQAMock: Bool = isRunningUIQAMock
    ) -> VoiceSDKReadinessSummary {
        if isUIQAMock {
            return VoiceSDKReadinessSummary(
                state: .mockASRTTS,
                title: "UIQA mock ASR/TTS，仅验证状态机",
                detail: "模拟器只证明回响状态、等待回信和 UI 合同，不证明真实语音识别或播放质量。",
                allowsProductionClosureClaim: false
            )
        }

        guard backendRuntimeConfigured, backendRuntimeTokenApplied else {
            return VoiceSDKReadinessSummary(
                state: .providerCredentialBlocked,
                title: "实时语音凭据代理尚未开放",
                detail: "客户端不会使用共享 Provider 密钥；当前保留文字回响和明确的能力阻断状态。",
                allowsProductionClosureClaim: false
            )
        }

        guard localConfigReady, productionVoiceSDKQualityVerified else {
            return VoiceSDKReadinessSummary(
                state: .productionSDKNeedsTrueDeviceQA,
                title: "生产语音待真机验收",
                detail: "后端 token 和本地配置已可用，仍需真机完成麦克风、ASR、TTS、播放路由、前后台和日志证据。",
                allowsProductionClosureClaim: false
            )
        }

        return VoiceSDKReadinessSummary(
            state: .productionSDKVerified,
            title: "生产语音已通过真机验收",
            detail: "只有真机证据包齐全且无阻塞问题时才允许使用该状态。",
            allowsProductionClosureClaim: true
        )
    }

    private static var isRunningUIQAMock: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

struct DialogEngineBindingHandle: Equatable, Sendable {
    fileprivate let bindingId: UUID
    fileprivate let ownerId: UUID
    let accountLease: AccountLease
}

/// Controls who owns the lifetime of a dialog session. Echo Live uses an
/// explicit user stop; other callers keep the existing keyword/idle behavior.
enum DialogSessionLifetimePolicy: Equatable, Sendable {
    case automatic
    case userControlledLive
}

enum DialogAudioSessionOwnershipPolicy {
    static func requiresCoordinator(
        lifetimePolicy: DialogSessionLifetimePolicy,
        hasExternalLease: Bool
    ) -> Bool {
        lifetimePolicy == .userControlledLive || hasExternalLease
    }

    static func allowsDirectConfiguration(
        lifetimePolicy: DialogSessionLifetimePolicy,
        hasExternalLease: Bool
    ) -> Bool {
        !requiresCoordinator(
            lifetimePolicy: lifetimePolicy,
            hasExternalLease: hasExternalLease
        )
    }
}

enum DialogTTSPlaybackTiming {
    static func expectedDuration(fromSentenceEnd data: Data) -> TimeInterval? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sentenceDuration = json["sentence_duration"] as? [String: Any],
              let endTime = sentenceDuration["sentence_end_time"] as? NSNumber else {
            return nil
        }
        let startTime = (sentenceDuration["sentence_start_time"] as? NSNumber)?.doubleValue ?? 0
        let duration = endTime.doubleValue - startTime
        return duration > 0 ? duration : nil
    }

    static func completionDelay(
        startedAt: Date,
        expectedDuration: TimeInterval?,
        now: Date = Date(),
        tailAllowance: TimeInterval = 0.2
    ) -> TimeInterval {
        guard let expectedDuration, expectedDuration > 0 else {
            return 0.35
        }
        let remaining = expectedDuration - max(0, now.timeIntervalSince(startedAt))
        return max(0.15, remaining + tailAllowance)
    }
}

enum DialogPCM16WaveEncoder {
    static func encode(
        pcmData: Data,
        sampleRate: UInt32 = 24_000,
        channelCount: UInt16 = 1
    ) -> Data? {
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = UInt16(bitsPerSample / 8)
        let blockAlignment = channelCount * bytesPerSample
        guard !pcmData.isEmpty,
              blockAlignment > 0,
              pcmData.count % Int(blockAlignment) == 0,
              pcmData.count <= Int(UInt32.max - 36) else {
            return nil
        }

        let payloadSize = UInt32(pcmData.count)
        let byteRate = sampleRate * UInt32(blockAlignment)
        var result = Data()
        result.reserveCapacity(44 + pcmData.count)
        result.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(36 + payloadSize, to: &result)
        result.append(contentsOf: "WAVE".utf8)
        result.append(contentsOf: "fmt ".utf8)
        appendLittleEndian(UInt32(16), to: &result)
        appendLittleEndian(UInt16(1), to: &result)
        appendLittleEndian(channelCount, to: &result)
        appendLittleEndian(sampleRate, to: &result)
        appendLittleEndian(byteRate, to: &result)
        appendLittleEndian(blockAlignment, to: &result)
        appendLittleEndian(bitsPerSample, to: &result)
        result.append(contentsOf: "data".utf8)
        appendLittleEndian(payloadSize, to: &result)
        result.append(pcmData)
        return result
    }

    static func containsAudibleSamples(_ pcmData: Data) -> Bool {
        guard pcmData.count >= 2 else { return false }
        return pcmData.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var offset = 0
            while offset + 1 < bytes.count {
                let bits = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
                if abs(Int(Int16(bitPattern: bits))) > 8 {
                    return true
                }
                offset += 2
            }
            return false
        }
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}

/// Selects who generates the semantic answer for a dialog session. Native Live
/// is provider-owned and receives the bound formal-memory snapshot at session
/// start. Backend authority is reserved for explicit one-shot/delegated flows.
enum DialogAnswerAuthority: Equatable, Sendable {
    case provider
    case dreamJourneyBackend
}

/// Keeps the production Live grounding contract in one testable value. The
/// default path binds the complete reviewed snapshot once at session start and
/// never submits the retired per-turn ChatRagText payload.
struct DialogLiveGroundingPlan: Equatable, Sendable {
    let usesTurnScopedKnowledgeContext: Bool
    let lifetimePolicy: DialogSessionLifetimePolicy
    let answerAuthority: DialogAnswerAuthority

    static let sessionSnapshot = DialogLiveGroundingPlan(
        usesTurnScopedKnowledgeContext: false,
        lifetimePolicy: .userControlledLive,
        answerAuthority: .provider
    )

    var usesBackendAnswerPerTurn: Bool {
        answerAuthority == .dreamJourneyBackend
    }
}

/// Keeps the native Live answer boundary explicit and independently testable.
/// Provider-owned, user-controlled Live turns are captured for persistence but
/// must never dispatch a second semantic answer through DreamJourneyBackend.
struct DialogLiveAnswerDispatchPolicy: Equatable, Sendable {
    static func shouldRequestBackendAnswer(
        isUserControlledLiveSessionOpen: Bool,
        lifetimePolicy: DialogSessionLifetimePolicy,
        answerAuthority: DialogAnswerAuthority
    ) -> Bool {
        !(isUserControlledLiveSessionOpen
            && lifetimePolicy == .userControlledLive
            && answerAuthority == .provider)
    }
}

/// Selects exactly one audible output for a dialog session. SpeechEngine's
/// internal player is the low-latency Live path; decoder PCM must not be
/// replayed by the app after the same audio has already been heard.
struct DialogEngineAudiblePlaybackPolicy: Equatable, Sendable {
    let providerPlayerEnabled: Bool
    let providerPlayerAudioCallbackEnabled: Bool
    let applicationPCMPlaybackEnabled: Bool
    let decoderObservationEnabled: Bool

    init(enablePlayer: Bool, usesDelegatedLivePlayback: Bool = false) {
        providerPlayerEnabled = enablePlayer
        providerPlayerAudioCallbackEnabled = enablePlayer
        applicationPCMPlaybackEnabled = false
        decoderObservationEnabled = enablePlayer && !usesDelegatedLivePlayback
    }
}

/// The recorder resume contract distinguishes a real provider directive from
/// an already-running recorder and from a rejected/inactive session. A Bool
/// cannot tell those cases apart at a recovery boundary.
enum DialogRecorderResumeOutcome: Equatable, Sendable {
    case directiveSent
    case alreadyRunning
    case sessionInactive
    case directiveRejected(code: Int)

    var isSuccess: Bool {
        switch self {
        case .directiveSent, .alreadyRunning:
            return true
        case .sessionInactive, .directiveRejected:
            return false
        }
    }

    var diagnosticCode: String {
        switch self {
        case .directiveSent:
            return "directiveSent"
        case .alreadyRunning:
            return "alreadyRunning"
        case .sessionInactive:
            return "sessionInactive"
        case .directiveRejected(let code):
            return "directiveRejected_\(code)"
        }
    }
}

/// Progress emitted by the provider-owned Live TTS route. The application
/// never infers playback completion from text length or elapsed time alone.
enum DialogEngineDelegatedPlaybackProgress: Equatable, Sendable {
    case providerAccepted(replyID: String)
    case audioActivityObserved(replyID: String)
    case audioStarted(replyID: String)
    case synthesisEnded(replyID: String)
    case audioFinished(replyID: String)
    case interrupted(replyID: String?)
    case failed(replyID: String?, code: String)

    var replyID: String? {
        switch self {
        case .providerAccepted(let replyID),
             .audioActivityObserved(let replyID),
             .audioStarted(let replyID),
             .synthesisEnded(let replyID),
             .audioFinished(let replyID):
            return replyID
        case .interrupted(let replyID), .failed(let replyID, _):
            return replyID
        }
    }
}

enum DialogEngineDelegatedPlaybackPhase: Equatable, Sendable {
    case idle
    case submitted
    case providerAccepted
    case audioStarted
    case synthesisEnded
    case audioFinished
    case interrupted
    case failed
}

/// Pure reducer for the delegated Live playback contract. It makes provider
/// reply identity and terminal transitions explicit and idempotent.
struct DialogEngineDelegatedPlaybackState: Equatable, Sendable {
    private(set) var phase: DialogEngineDelegatedPlaybackPhase = .idle
    private(set) var replyID: String? = nil

    mutating func reset() {
        phase = .idle
        replyID = nil
    }

    mutating func submit() {
        phase = .submitted
        replyID = nil
    }

    @discardableResult
    mutating func apply(_ progress: DialogEngineDelegatedPlaybackProgress) -> Bool {
        switch progress {
        case .providerAccepted(let nextReplyID):
            guard !nextReplyID.isEmpty else { return false }
            guard phase == .submitted || phase == .providerAccepted else { return false }
            guard replyID == nil || replyID == nextReplyID else { return false }
            replyID = nextReplyID
            phase = .providerAccepted
            return true

        case .audioStarted(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded else { return false }
            phase = .audioStarted
            return true

        case .audioActivityObserved(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded else { return false }
            return true

        case .synthesisEnded(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded else { return false }
            phase = .synthesisEnded
            return true

        case .audioFinished(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded
                    || phase == .audioFinished else { return false }
            phase = .audioFinished
            return true

        case .interrupted(let nextReplyID):
            guard phase != .idle,
                  phase != .audioFinished,
                  phase != .failed,
                  nextReplyID == nil || nextReplyID == replyID else { return false }
            phase = .interrupted
            return true

        case .failed(let nextReplyID, _):
            guard phase != .idle,
                  phase != .audioFinished,
                  nextReplyID == nil || nextReplyID == replyID else { return false }
            phase = .failed
            return true
        }
    }

    private func matches(_ nextReplyID: String) -> Bool {
        !nextReplyID.isEmpty && replyID == nextReplyID
    }
}

struct DialogProviderEventMetadata: Equatable, Sendable {
    let questionID: String?
    let replyID: String?
    let ttsType: String?

    init(data: Data) {
        let object = try? JSONSerialization.jsonObject(with: data)
        questionID = Self.firstString(
            in: object,
            keys: ["question_id", "questionId"]
        )
        replyID = Self.firstString(
            in: object,
            keys: ["reply_id", "replyId"]
        )
        ttsType = Self.firstString(
            in: object,
            keys: ["tts_type", "ttsType"]
        )
    }

    private static func firstString(in value: Any?, keys: Set<String>) -> String? {
        if let dictionary = value as? [String: Any] {
            for key in keys {
                if let result = dictionary[key] as? String,
                   !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return result
                }
            }
            for key in dictionary.keys.sorted() {
                if let result = firstString(in: dictionary[key], keys: keys) {
                    return result
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let result = firstString(in: child, keys: keys) {
                    return result
                }
            }
        }
        return nil
    }
}

enum DialogProviderASRTextSource: String, Equatable, Sendable {
    case resultsText
    case originText
    case legacyText
    case legacyResult
    case legacyUtterance
}

struct DialogProviderASRParseResult: Equatable, Sendable {
    let text: String
    let finalityEvidence: NativeLiveCanonicalTranscriptFinalityEvidence
    let evidenceSource: NativeLiveCanonicalTranscriptEvidenceSource
    let textSource: DialogProviderASRTextSource

    var isFinal: Bool { finalityEvidence == .explicitFinal }
}

enum DialogProviderASRParser {
    static func parse(_ data: Data) -> DialogProviderASRParseResult? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let results = json["results"] as? [[String: Any]], let first = results.first {
            let primary = normalized(first["text"] as? String)
            let origin = normalized((json["extra"] as? [String: Any])?["origin_text"] as? String)
            if let text = primary ?? origin {
                let evidence = strictBoolean(first["is_interim"]).map {
                    $0 ? NativeLiveCanonicalTranscriptFinalityEvidence.explicitInterim : .explicitFinal
                } ?? (first.keys.contains("is_interim") ? .invalid : .unknown)
                return DialogProviderASRParseResult(
                    text: text,
                    finalityEvidence: evidence,
                    evidenceSource: evidence == .invalid ? .invalid : (evidence == .unknown ? .absent : .resultsIsInterim),
                    textSource: primary != nil ? .resultsText : .originText
                )
            }
        }
        let topLevelEvidence = strictLegacyDefinite(json["definite"])
        if let text = normalized(json["text"] as? String) {
            return legacyResult(text, source: .legacyText, evidence: topLevelEvidence, raw: json["definite"])
        }
        if let text = normalized(json["result"] as? String) {
            return legacyResult(text, source: .legacyResult, evidence: topLevelEvidence, raw: json["definite"])
        }
        if let utterance = (json["utterances"] as? [[String: Any]])?.first,
           let text = normalized(utterance["text"] as? String) {
            let raw = utterance["definite"] ?? json["definite"]
            return legacyResult(text, source: .legacyUtterance, evidence: strictLegacyDefinite(raw), raw: raw)
        }
        return nil
    }

    private static func legacyResult(
        _ text: String,
        source: DialogProviderASRTextSource,
        evidence: NativeLiveCanonicalTranscriptFinalityEvidence?,
        raw: Any?
    ) -> DialogProviderASRParseResult {
        DialogProviderASRParseResult(
            text: text,
            finalityEvidence: evidence ?? (raw == nil ? .unknown : .invalid),
            evidenceSource: raw == nil ? .absent : (evidence == nil ? .invalid : .legacyDefinite),
            textSource: source
        )
    }

    private static func strictBoolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func strictLegacyDefinite(_ value: Any?) -> NativeLiveCanonicalTranscriptFinalityEvidence? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        switch number.intValue {
        case 0 where number.doubleValue == 0: return .explicitInterim
        case 1 where number.doubleValue == 1: return .explicitFinal
        default: return nil
        }
    }

    private static func normalized(_ text: String?) -> String? {
        guard let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else { return nil }
        return normalized
    }
}

enum DialogProviderCanonicalOwnerFinalityMapper {
    static func finality(
        evidence: NativeLiveCanonicalTranscriptFinalityEvidence
    ) -> NativeLiveCanonicalTranscriptFinality {
        evidence == .explicitFinal || evidence == .confirmed ? .complete : .interim
    }
}

enum DialogProviderCanonicalIngressKind: String, Equatable, Sendable {
    case asrInfo
    case asrResponse
    case asrEnded
    case queryConfirmed
    case other

    var ownerIngressKind: NativeLiveCanonicalTranscriptIngressKind? {
        switch self {
        case .asrInfo: return .asrInfo
        case .asrResponse: return .asrResponse
        case .asrEnded, .queryConfirmed, .other: return nil
        }
    }
}

/// Keeps the locked SpeechEngine event-code contract in one place so the
/// production callback and deterministic tests exercise the same classifier.
enum DialogProviderSDKEventClassifier {
    static let ttsSentenceStart = 3008
    static let ttsSentenceEnd = 3009
    static let ttsEnded = 3011
    static let asrInfo = 3012
    static let asrResponse = 3013
    static let asrEnded = 3014
    static let chatResponse = 3015
    static let chatEnded = 3016
    static let queryConfirmed = 3021

    static func canonicalIngressKind(rawValue: Int) -> DialogProviderCanonicalIngressKind {
        switch rawValue {
        case asrInfo: return .asrInfo
        case asrResponse: return .asrResponse
        case asrEnded: return .asrEnded
        case queryConfirmed: return .queryConfirmed
        default: return .other
        }
    }
}

struct DialogProviderCanonicalIngressResult: Equatable, Sendable {
    let callbackOrdinal: UInt64
    let metadata: DialogProviderEventMetadata
    let member: NativeLiveCanonicalTranscriptMember?
    let event: NativeLiveCanonicalTranscriptEvent?
}

struct DialogCanonicalTranscriptDeliveryBinding {
    let reserve: (NativeLiveCanonicalTranscriptMember) -> Bool
    let deliver: (
        NativeLiveCanonicalTranscriptMember?,
        NativeLiveCanonicalTranscriptEvent?
    ) -> Void

    init(
        deliver: @escaping (
            NativeLiveCanonicalTranscriptMember?,
            NativeLiveCanonicalTranscriptEvent?
        ) -> Void
    ) {
        reserve = { _ in true }
        self.deliver = deliver
    }

    init(
        reserve: @escaping (NativeLiveCanonicalTranscriptMember) -> Bool,
        deliver: @escaping (
            NativeLiveCanonicalTranscriptMember?,
            NativeLiveCanonicalTranscriptEvent?
        ) -> Void
    ) {
        self.reserve = reserve
        self.deliver = deliver
    }
}

private struct DialogProviderCanonicalIngressBinding {
    let engineGeneration: UUID
    let dialogOperationID: UUID
    let reserve: (NativeLiveCanonicalTranscriptMember) -> Bool
    let deliver: (
        NativeLiveCanonicalTranscriptMember?,
        NativeLiveCanonicalTranscriptEvent?
    ) -> Void
}

/// Freezes provider identity and receive order at the SDK callback boundary.
/// The active question window is used only when the provider omits an ID from
/// a later packet in the same ordered ASR stream.
final class DialogProviderCanonicalIngressRouter {
    typealias DeliveryScheduler = (@escaping () -> Void) -> Void

    private let lock = NSLock()
    private var ordinal: UInt64 = 0
    private var binding: DialogProviderCanonicalIngressBinding?
    private var activeQuestionID: String?
    private var activeQuestionMember: NativeLiveCanonicalTranscriptMember?
    private var latestOwnerObservations: [String: NativeLiveCanonicalTranscriptEvent] = [:]
    private var latestTrustedOwnerFinalObservations:
        [String: NativeLiveCanonicalTranscriptEvent] = [:]
    private var boundarySeenQuestionIDs = Set<String>()
    private var registeredQuestionIDs = Set<String>()
    private var deliveryScheduler: DeliveryScheduler = { $0() }

    func accepts(engineGeneration: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return binding?.engineGeneration == engineGeneration
    }

    @discardableResult
    func deliverAssistant(
        _ event: NativeLiveCanonicalTranscriptEvent,
        engineGeneration: UUID
    ) -> Bool {
        freezeAssistant(
            event,
            metadata: DialogProviderEventMetadata(data: Data()),
            engineGeneration: engineGeneration
        ) != nil
    }

    func freezeAssistant(
        _ event: NativeLiveCanonicalTranscriptEvent,
        metadata: DialogProviderEventMetadata,
        engineGeneration: UUID
    ) -> DialogProviderCanonicalIngressResult? {
        lock.lock()
        guard let binding, binding.engineGeneration == engineGeneration else {
            lock.unlock()
            return nil
        }
        ordinal &+= 1
        let assistantOrdinal = ordinal
        let handoffMember = NativeLiveCanonicalTranscriptMember(
            canonicalTurnID: event.canonicalTurnID,
            handoffID: "\(event.canonicalTurnID):handoff:\(assistantOrdinal)",
            role: event.role,
            capturedAt: event.capturedAt,
            ingressOrdinal: assistantOrdinal,
            ingressKind: .assistantStream
        )
        guard binding.reserve(handoffMember) else {
            lock.unlock()
            return nil
        }
        let deliver = binding.deliver
        let deliveryScheduler = deliveryScheduler
        lock.unlock()
        deliveryScheduler { deliver(handoffMember, event) }
        return DialogProviderCanonicalIngressResult(
            callbackOrdinal: assistantOrdinal,
            metadata: metadata,
            member: handoffMember,
            event: event
        )
    }

    #if DEBUG
    func setDeliverySchedulerForTesting(_ scheduler: @escaping DeliveryScheduler) {
        lock.lock()
        deliveryScheduler = scheduler
        lock.unlock()
    }
    #endif

    func install(
        engineGeneration: UUID,
        dialogOperationID: UUID,
        reserve: @escaping (NativeLiveCanonicalTranscriptMember) -> Bool = { _ in true },
        deliver: @escaping (
            NativeLiveCanonicalTranscriptMember?,
            NativeLiveCanonicalTranscriptEvent?
        ) -> Void
    ) {
        lock.lock()
        ordinal = 0
        activeQuestionID = nil
        activeQuestionMember = nil
        latestOwnerObservations.removeAll()
        latestTrustedOwnerFinalObservations.removeAll()
        boundarySeenQuestionIDs.removeAll()
        registeredQuestionIDs.removeAll()
        binding = DialogProviderCanonicalIngressBinding(
            engineGeneration: engineGeneration,
            dialogOperationID: dialogOperationID,
            reserve: reserve,
            deliver: deliver
        )
        lock.unlock()
    }

    @discardableResult
    func close(expectedDialogOperationID: UUID? = nil) -> Bool {
        lock.lock()
        let didClose = expectedDialogOperationID == nil
            || binding?.dialogOperationID == expectedDialogOperationID
        if didClose {
            binding = nil
            activeQuestionID = nil
            activeQuestionMember = nil
            latestOwnerObservations.removeAll()
            latestTrustedOwnerFinalObservations.removeAll()
            boundarySeenQuestionIDs.removeAll()
            registeredQuestionIDs.removeAll()
        }
        lock.unlock()
        return didClose
    }

    func freeze(
        kind: DialogProviderCanonicalIngressKind,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> DialogProviderCanonicalIngressResult? {
        let metadata = DialogProviderEventMetadata(data: data)
        lock.lock()
        guard let binding, binding.engineGeneration == engineGeneration else {
            lock.unlock()
            return nil
        }
        ordinal &+= 1
        let callbackOrdinal = ordinal
        let ownerIngressKind = kind.ownerIngressKind
        let explicitQuestionID = ownerIngressKind == nil
            ? nil
            : Self.normalized(metadata.questionID)
        var boundaryPacket: (
            NativeLiveCanonicalTranscriptMember,
            NativeLiveCanonicalTranscriptEvent
        )?
        var boundaryFollowsCurrentEvent = false
        if let explicitQuestionID {
            // An already registered explicit ID may be a late packet for an
            // older question. It still belongs to that question, but must not
            // roll the identifier-less stream window back from the newer one.
            if !registeredQuestionIDs.contains(explicitQuestionID) {
                boundaryPacket = sealActiveQuestionPacket(handoffOrdinal: callbackOrdinal)
                activeQuestionID = explicitQuestionID
                activeQuestionMember = nil
            }
        }
        let questionID = explicitQuestionID ?? activeQuestionID
        let canonicalID = questionID.map {
            [
                engineGeneration.uuidString.lowercased(),
                OwnerTruthInterviewNaturalInputMessageRole.owner.rawValue,
                $0,
            ].joined(separator: ":")
        }
        let isNewMember = questionID.map { registeredQuestionIDs.insert($0).inserted } ?? false
        let member = isNewMember ? canonicalID.map {
            NativeLiveCanonicalTranscriptMember(
                canonicalTurnID: $0,
                handoffID: "\($0):handoff:\(callbackOrdinal)",
                role: .owner,
                capturedAt: capturedAt,
                ingressOrdinal: callbackOrdinal,
                ingressKind: ownerIngressKind
            )
        } : nil
        if let member { activeQuestionMember = member }
        let parsed = Self.parse(kind: kind, data: data)
        let event: NativeLiveCanonicalTranscriptEvent?
        if let canonicalID, let parsed {
            event = NativeLiveCanonicalTranscriptEvent(
                canonicalTurnID: canonicalID,
                role: .owner,
                text: parsed.text,
                finality: DialogProviderCanonicalOwnerFinalityMapper.finality(
                    evidence: parsed.finalityEvidence
                ),
                finalityEvidence: parsed.finalityEvidence,
                evidenceSource: parsed.evidenceSource,
                observationID: "provider-callback-\(callbackOrdinal)",
                ingressOrdinal: callbackOrdinal,
                sealing: .observeOnly,
                capturedAt: capturedAt
            )
        } else {
            event = nil
        }
        if let event {
            latestOwnerObservations[event.canonicalTurnID] = event
            if event.finality == .complete,
               event.finalityEvidence == .explicitFinal {
                latestTrustedOwnerFinalObservations[event.canonicalTurnID] = event
            }
            if event.finalityEvidence == .explicitFinal,
               boundarySeenQuestionIDs.contains(questionID ?? "") {
                boundaryPacket = sealActiveQuestionPacket(
                    handoffOrdinal: callbackOrdinal
                ) ?? boundaryPacket
                boundaryFollowsCurrentEvent = boundaryPacket != nil
            }
        }
        if kind == .asrEnded {
            let boundaryQuestionID = Self.normalized(metadata.questionID)
            if boundaryQuestionID == nil || boundaryQuestionID == activeQuestionID {
                let activeCanonicalID = activeQuestionMember?.canonicalTurnID
                let hasTrustedFinal = activeCanonicalID.flatMap {
                    latestTrustedOwnerFinalObservations[$0]
                } != nil
                let sealedPacket = sealActiveQuestionPacket(
                    handoffOrdinal: callbackOrdinal
                )
                boundaryPacket = sealedPacket ?? boundaryPacket
                if !hasTrustedFinal, let activeQuestionID {
                    boundarySeenQuestionIDs.insert(activeQuestionID)
                }
            }
        }
        let eventHandoffMember: NativeLiveCanonicalTranscriptMember? = {
            if let member { return member }
            guard let event, let activeQuestionMember else { return nil }
            return NativeLiveCanonicalTranscriptMember(
                canonicalTurnID: event.canonicalTurnID,
                handoffID: "\(event.canonicalTurnID):handoff:\(callbackOrdinal)",
                role: event.role,
                capturedAt: activeQuestionMember.capturedAt,
                ingressOrdinal: activeQuestionMember.ingressOrdinal,
                ingressKind: activeQuestionMember.ingressKind
            )
        }()
        if let eventHandoffMember, !binding.reserve(eventHandoffMember) {
            if let questionID {
                if member != nil {
                    registeredQuestionIDs.remove(questionID)
                    if activeQuestionID == questionID {
                        activeQuestionID = nil
                    }
                }
            }
            Self.recordIngressDiagnostic(
                kind: kind,
                callbackOrdinal: callbackOrdinal,
                metadata: metadata,
                parsed: parsed,
                memberRegistration: "rejected",
                eventUpsert: event == nil ? "none" : "notDelivered"
            )
            lock.unlock()
            return nil
        }
        if let boundaryPacket, !binding.reserve(boundaryPacket.0) {
            Self.recordIngressDiagnostic(
                kind: kind,
                callbackOrdinal: callbackOrdinal,
                metadata: metadata,
                parsed: parsed,
                memberRegistration: "boundaryRejected",
                eventUpsert: "notDelivered"
            )
            lock.unlock()
            return nil
        }
        let deliver = binding.deliver
        let deliveryScheduler = deliveryScheduler
        lock.unlock()

        if let boundaryPacket, !boundaryFollowsCurrentEvent {
            deliveryScheduler {
                deliver(boundaryPacket.0, boundaryPacket.1)
            }
        }
        if eventHandoffMember != nil || event != nil {
            deliveryScheduler {
                deliver(eventHandoffMember, event)
            }
        }
        if let boundaryPacket, boundaryFollowsCurrentEvent {
            deliveryScheduler {
                deliver(boundaryPacket.0, boundaryPacket.1)
            }
        }
        Self.recordIngressDiagnostic(
            kind: kind,
            callbackOrdinal: callbackOrdinal,
            metadata: metadata,
            parsed: parsed,
            memberRegistration: member == nil ? "none" : "accepted",
            eventUpsert: event == nil ? "none" : "scheduled"
        )
        return DialogProviderCanonicalIngressResult(
            callbackOrdinal: callbackOrdinal,
            metadata: metadata,
            member: member,
            event: event
        )
    }

    @discardableResult
    func sealActiveOwnerForStop(engineGeneration: UUID) -> Bool {
        lock.lock()
        ordinal &+= 1
        let stopOrdinal = ordinal
        guard let binding, binding.engineGeneration == engineGeneration,
              let packet = sealActiveQuestionPacket(handoffOrdinal: stopOrdinal),
              binding.reserve(packet.0) else {
            lock.unlock()
            return false
        }
        let deliver = binding.deliver
        let deliveryScheduler = deliveryScheduler
        lock.unlock()
        deliveryScheduler { deliver(packet.0, packet.1) }
        return true
    }

    private func sealActiveQuestionPacket(handoffOrdinal: UInt64) -> (
        NativeLiveCanonicalTranscriptMember,
        NativeLiveCanonicalTranscriptEvent
    )? {
        guard let member = activeQuestionMember else { return nil }
        let trustedFinal = latestTrustedOwnerFinalObservations[member.canonicalTurnID]
        guard let observation = trustedFinal
            ?? latestOwnerObservations[member.canonicalTurnID] else { return nil }
        if trustedFinal != nil {
            latestOwnerObservations.removeValue(forKey: member.canonicalTurnID)
            latestTrustedOwnerFinalObservations.removeValue(forKey: member.canonicalTurnID)
            boundarySeenQuestionIDs.remove(activeQuestionID ?? "")
        }
        let sealingMember = NativeLiveCanonicalTranscriptMember(
            canonicalTurnID: member.canonicalTurnID,
            handoffID: "\(member.canonicalTurnID):seal:\(handoffOrdinal)",
            role: member.role,
            capturedAt: member.capturedAt,
            ingressOrdinal: member.ingressOrdinal,
            ingressKind: member.ingressKind
        )
        return (sealingMember, NativeLiveCanonicalTranscriptEvent(
            canonicalTurnID: observation.canonicalTurnID,
            role: observation.role,
            text: observation.text,
            finality: observation.finality,
            finalityEvidence: observation.finalityEvidence,
            evidenceSource: observation.evidenceSource,
            observationID: observation.observationID,
            ingressOrdinal: observation.ingressOrdinal,
            sealing: .observeAndSeal,
            capturedAt: observation.capturedAt
        ))
    }

    #if DEBUG
    @discardableResult
    func deliverAssistantForTesting(
        replyID: String,
        text: String,
        engineGeneration: UUID,
        capturedAt: Date
    ) -> Bool {
        guard let normalizedReplyID = Self.normalized(replyID),
              let normalizedText = Self.normalized(text) else { return false }
        return deliverAssistant(NativeLiveCanonicalTranscriptEvent(
            canonicalTurnID: [
                engineGeneration.uuidString.lowercased(),
                OwnerTruthInterviewNaturalInputMessageRole.assistant.rawValue,
                normalizedReplyID,
            ].joined(separator: ":"),
            role: .assistant,
            text: normalizedText,
            finality: .complete,
            finalityEvidence: .confirmed,
            evidenceSource: .assistantStream,
            sealing: .observeAndSeal,
            capturedAt: capturedAt
        ), engineGeneration: engineGeneration)
    }
    #endif

    private static func parse(
        kind: DialogProviderCanonicalIngressKind,
        data: Data
    ) -> DialogProviderASRParseResult? {
        switch kind {
        case .asrInfo, .asrResponse:
            return DialogProviderASRParser.parse(data)
        case .asrEnded, .queryConfirmed, .other:
            return nil
        }
    }

    private static func parseQueryConfirmedText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return normalized(String(data: data, encoding: .utf8)?.trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "\""))
            ))
        }
        for key in ["text", "query", "content", "input", "result", "message"] {
            if let text = normalized(json[key] as? String) { return text }
        }
        if let asr = json["asr"] as? [String: Any] {
            return normalized(asr["text"] as? String)
                ?? normalized(asr["result"] as? String)
        }
        return nil
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private static func recordIngressDiagnostic(
        kind: DialogProviderCanonicalIngressKind,
        callbackOrdinal: UInt64,
        metadata: DialogProviderEventMetadata,
        parsed: DialogProviderASRParseResult?,
        memberRegistration: String,
        eventUpsert: String
    ) {
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "canonicalIngressClassified",
            states: [
                "kind": kind.rawValue,
                "hasQuestionIdentity": metadata.questionID == nil ? "false" : "true",
                "hasBody": parsed == nil ? "false" : "true",
                "finality": parsed.map {
                    DialogProviderCanonicalOwnerFinalityMapper.finality(
                        evidence: $0.finalityEvidence
                    ).rawValue
                } ?? "none",
                "memberRegistration": memberRegistration,
                "eventUpsert": eventUpsert,
            ],
            counts: ["callbackOrdinal": Int(callbackOrdinal)]
        )
    }
}

enum DialogProviderReplyCorrelation: String, Equatable, Sendable {
    case matched
    case unobserved
    case ambiguousReply
    case staleQuestion
    case staleGeneration
}

enum DialogProviderPlaybackProgress: Equatable, Sendable {
    case synthesisEnded
    case playerStarted
    case playerFinished
}

enum DialogProviderPlaybackOutcome: Equatable, Sendable {
    case ignored
    case waiting
    case drained
}

/// SpeechEngine 0.0.14.6.1 drops the core's 2001/2002 player events before
/// its public listener (the header still declares 3019/3020). Verify actual
/// player PCM instead: every nonzero sample must match the decoded stream,
/// synthesis must be sealed, then 200 ms of real player silence must follow.
/// No elapsed-time or text-length completion, and no second audio player.
struct DialogProviderPCMDrainVerifier {
    private(set) var generation: UUID?
    private(set) var replyID: String?
    private(set) var decodedSamples = 0
    private(set) var playedSamples = 0
    private(set) var silentPlayerSamples = 0
    private(set) var synthesisEnded = false
    private(set) var didDrain = false
    private(set) var invalid = false
    private var decodedHash = SHA256()
    private var playedHash = SHA256()
    // The canonical Dialog downstream PCM is 24 kHz, mono, signed Int16.
    static let requiredSilentSamples = 4_800
    static let maximumSamples = 24_000 * 300

    mutating func reset() { self = Self() }

    private mutating func bind(replyID: String?, generation: UUID) -> Bool {
        guard let replyID, !replyID.isEmpty, !invalid, !didDrain else { return false }
        if self.replyID == nil { self.replyID = replyID; self.generation = generation }
        return self.replyID == replyID && self.generation == generation
    }

    private static func audibleSamples(_ data: Data) -> Data? {
        guard data.count % 2 == 0 else { return nil }
        var result = Data()
        result.reserveCapacity(data.count)
        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for i in stride(from: 0, to: bytes.count, by: 2) {
                // Ignore exact zero padding only, not quiet speech. SDK player
                // callbacks include underrun/idle zeros absent from decoder PCM.
                if bytes[i] != 0 || bytes[i + 1] != 0 {
                    result.append(bytes[i]); result.append(bytes[i + 1])
                }
            }
        }
        return result
    }

    mutating func decoded(_ data: Data, replyID: String?, generation: UUID) {
        guard bind(replyID: replyID, generation: generation) else { return }
        guard !synthesisEnded, let samples = Self.audibleSamples(data) else {
            invalid = true; return
        }
        decodedSamples += samples.count / 2
        if decodedSamples > Self.maximumSamples { invalid = true; return }
        decodedHash.update(data: samples)
        silentPlayerSamples = 0
    }

    mutating func synthesized(replyID: String?, generation: UUID) {
        guard bind(replyID: replyID, generation: generation) else { return }
        synthesisEnded = true
        // Require observed silence after the terminal synthesis event.
        silentPlayerSamples = 0
    }

    mutating func played(_ data: Data, replyID: String?, generation: UUID) -> Bool {
        guard bind(replyID: replyID, generation: generation) else { return false }
        guard let samples = Self.audibleSamples(data) else { invalid = true; return false }
        playedSamples += samples.count / 2
        if playedSamples > Self.maximumSamples { invalid = true; return false }
        playedHash.update(data: samples)
        if samples.isEmpty && synthesisEnded {
            silentPlayerSamples = min(Self.requiredSilentSamples, silentPlayerSamples + data.count / 2)
        } else { silentPlayerSamples = 0 }
        guard synthesisEnded, decodedSamples > 0, playedSamples == decodedSamples,
              silentPlayerSamples >= Self.requiredSilentSamples,
              decodedHash.finalize() == playedHash.finalize() else { return false }
        didDrain = true
        return true
    }
}

struct DialogProviderReplyPlaybackState: Equatable, Sendable {
    private(set) var generation: UUID?
    private(set) var replyID: String?
    private(set) var synthesisEnded = false
    private(set) var activePlayerSegments = 0
    private(set) var observedPlayerStart = false
    private(set) var didDrain = false

    mutating func reset() {
        generation = nil
        replyID = nil
        synthesisEnded = false
        activePlayerSegments = 0
        observedPlayerStart = false
        didDrain = false
    }

    mutating func receive(
        _ progress: DialogProviderPlaybackProgress,
        replyID: String?,
        generation: UUID
    ) -> DialogProviderPlaybackOutcome {
        guard let replyID,
              !replyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .ignored
        }
        if self.replyID == nil {
            self.replyID = replyID
            self.generation = generation
        }
        guard self.replyID == replyID, self.generation == generation, !didDrain else {
            return .ignored
        }
        switch progress {
        case .synthesisEnded:
            synthesisEnded = true
        case .playerStarted:
            observedPlayerStart = true
            activePlayerSegments += 1
        case .playerFinished:
            guard activePlayerSegments > 0 else { return .ignored }
            activePlayerSegments -= 1
        }
        if synthesisEnded, observedPlayerStart, activePlayerSegments == 0 {
            didDrain = true
            return .drained
        }
        return .waiting
    }
}

struct DialogProviderInterruptionState: Equatable, Sendable {
    private(set) var generation: UUID?
    private(set) var audibleQuestionID: String?
    private var claimedQuestionIDs: Set<String> = []

    mutating func beginSession(generation: UUID) {
        self.generation = generation
        audibleQuestionID = nil
        claimedQuestionIDs.removeAll()
    }

    mutating func beginAudibleReply(questionID: String?, generation: UUID) {
        guard self.generation == generation,
              let questionID,
              !questionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        audibleQuestionID = questionID
    }

    mutating func clearAudibleReply() {
        audibleQuestionID = nil
    }

    mutating func claimNewSpokenQuestion(
        incomingQuestionID: String?,
        currentQuestionID: String?,
        hasRecognizedSpeech: Bool,
        generation: UUID
    ) -> Bool {
        guard self.generation == generation,
              hasRecognizedSpeech,
              let incomingQuestionID,
              incomingQuestionID == currentQuestionID,
              incomingQuestionID != audibleQuestionID,
              !claimedQuestionIDs.contains(incomingQuestionID) else {
            return false
        }
        claimedQuestionIDs.insert(incomingQuestionID)
        return true
    }
}

struct DialogProviderTurnCorrelationState: Equatable, Sendable {
    private(set) var generation: UUID?
    private(set) var turnSequence = 0
    private(set) var currentQuestionID: String?
    private(set) var currentReplyID: String?
    private var observedQuestionIDs: Set<String> = []
    private var replyQuestionIDs: [String: String] = [:]

    mutating func beginSession(generation: UUID) {
        self.generation = generation
        turnSequence = 0
        currentQuestionID = nil
        currentReplyID = nil
        observedQuestionIDs.removeAll()
        replyQuestionIDs.removeAll()
    }

    @discardableResult
    mutating func observeQuestion(
        id: String?,
        generation: UUID
    ) -> Int? {
        guard self.generation == generation else { return nil }
        guard let id,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return currentQuestionID == nil ? nil : turnSequence
        }
        if currentQuestionID != id {
            guard !observedQuestionIDs.contains(id) else { return nil }
            turnSequence += 1
            currentQuestionID = id
            currentReplyID = nil
            observedQuestionIDs.insert(id)
        }
        return turnSequence
    }

    mutating func observeReply(
        questionID: String?,
        replyID: String?,
        generation: UUID
    ) -> DialogProviderReplyCorrelation {
        guard self.generation == generation else { return .staleGeneration }
        guard let replyID,
              !replyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .unobserved
        }
        if let boundQuestionID = replyQuestionIDs[replyID] {
            guard boundQuestionID == currentQuestionID else { return .staleQuestion }
            if let questionID, questionID != boundQuestionID { return .staleQuestion }
            currentReplyID = replyID
            return .matched
        }
        if let questionID {
            guard questionID == currentQuestionID else { return .staleQuestion }
            replyQuestionIDs[replyID] = questionID
        } else if let currentReplyID, currentReplyID != replyID {
            // Without a question binding, a different reply cannot safely be
            // assigned to the current turn. It may be a late callback from the
            // preceding answer.
            return .ambiguousReply
        } else if let currentQuestionID {
            replyQuestionIDs[replyID] = currentQuestionID
        }
        currentReplyID = replyID
        return .matched
    }
}

struct DialogProviderCanonicalReplyTextState: Equatable, Sendable {
    private(set) var replyID: String?
    private(set) var text = ""

    mutating func reset() {
        replyID = nil
        text = ""
    }

    mutating func beginReply(_ nextReplyID: String?) {
        guard let nextReplyID,
              !nextReplyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard replyID != nextReplyID else { return }
        replyID = nextReplyID
        text = ""
    }

    @discardableResult
    mutating func update(_ nextText: String, replyID: String?) -> String {
        beginReply(replyID)
        let normalized = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return text }
        if normalized.hasPrefix(text) {
            text = normalized
        } else if !text.hasSuffix(normalized) {
            text += normalized
        }
        return text
    }

    mutating func replace(_ nextText: String, replyID: String?) {
        beginReply(replyID)
        text = nextText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DialogProviderCanonicalAssistantStreamKind: Equatable, Sendable {
    case response
    case ended
}

/// Shared by the SDK ChatResponse/ChatEnded path and deterministic local
/// assembly tests. Local packets exercise the production fragment/final
/// contract but are never reported as real SDK evidence.
struct DialogProviderCanonicalAssistantStreamState: Equatable, Sendable {
    private(set) var replyID: String?
    private(set) var text = ""
    private var replyTexts: [String: String] = [:]
    private var replyOrder: [String] = []
    private var completedReplyIDs = Set<String>()
    private static let maximumRetainedReplyCount = 32

    mutating func reset() {
        replyID = nil
        text = ""
        replyTexts.removeAll()
        replyOrder.removeAll()
        completedReplyIDs.removeAll()
    }

    mutating func consume(
        kind: DialogProviderCanonicalAssistantStreamKind,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date
    ) -> NativeLiveCanonicalTranscriptEvent? {
        let metadata = DialogProviderEventMetadata(data: data)
        guard let nextReplyID = metadata.replyID?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !nextReplyID.isEmpty else {
            return nil
        }
        guard !completedReplyIDs.contains(nextReplyID) else { return nil }
        replyID = nextReplyID
        var replyText = replyTexts[nextReplyID] ?? ""
        if replyTexts[nextReplyID] == nil {
            replyOrder.append(nextReplyID)
        }

        switch kind {
        case .response:
            guard let fragment = Self.textFragment(from: data) else { return nil }
            if fragment.hasPrefix(replyText) {
                replyText = fragment
            } else if !replyText.hasSuffix(fragment) {
                replyText += fragment
            }
            guard !replyText.isEmpty else { return nil }
            replyTexts[nextReplyID] = replyText
            text = replyText
            trimReplyBuffersIfNeeded()
            return event(
                engineGeneration: engineGeneration,
                replyID: nextReplyID,
                text: replyText,
                finality: .interim,
                capturedAt: capturedAt
            )
        case .ended:
            if let terminalText = Self.textFragment(from: data) {
                if terminalText.hasPrefix(replyText) {
                    replyText = terminalText
                } else if !replyText.hasSuffix(terminalText) {
                    replyText += terminalText
                }
            }
            guard !replyText.isEmpty else { return nil }
            replyTexts.removeValue(forKey: nextReplyID)
            replyOrder.removeAll { $0 == nextReplyID }
            completedReplyIDs.insert(nextReplyID)
            text = replyText
            trimReplyBuffersIfNeeded()
            return event(
                engineGeneration: engineGeneration,
                replyID: nextReplyID,
                text: replyText,
                finality: .complete,
                capturedAt: capturedAt
            )
        }
    }

    private mutating func trimReplyBuffersIfNeeded() {
        while replyOrder.count > Self.maximumRetainedReplyCount {
            let expired = replyOrder.removeFirst()
            replyTexts.removeValue(forKey: expired)
        }
    }

    private func event(
        engineGeneration: UUID,
        replyID: String,
        text: String,
        finality: NativeLiveCanonicalTranscriptFinality,
        capturedAt: Date
    ) -> NativeLiveCanonicalTranscriptEvent {
        NativeLiveCanonicalTranscriptEvent(
            canonicalTurnID: [
                engineGeneration.uuidString.lowercased(),
                OwnerTruthInterviewNaturalInputMessageRole.assistant.rawValue,
                replyID,
            ].joined(separator: ":"),
            role: .assistant,
            text: text,
            finality: finality,
            finalityEvidence: finality == .complete ? .confirmed : .unknown,
            evidenceSource: .assistantStream,
            sealing: finality == .complete ? .observeAndSeal : .observeOnly,
            capturedAt: capturedAt
        )
    }

    private static func textFragment(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        for key in ["text", "content", "message", "delta"] {
            if let value = json[key] as? String {
                let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty { return normalized }
            }
        }
        return nil
    }
}

@discardableResult
private func deliverCanonicalAssistantStreamPacket(
    state: inout DialogProviderCanonicalAssistantStreamState,
    router: DialogProviderCanonicalIngressRouter,
    kind: DialogProviderCanonicalAssistantStreamKind,
    data: Data,
    engineGeneration: UUID,
    capturedAt: Date
) -> NativeLiveCanonicalTranscriptEvent? {
    guard router.accepts(engineGeneration: engineGeneration),
          let event = state.consume(
        kind: kind,
        data: data,
        engineGeneration: engineGeneration,
        capturedAt: capturedAt
    ), router.deliverAssistant(event, engineGeneration: engineGeneration) else {
        return nil
    }
    return event
}

private enum DialogProviderCanonicalMemoryEventKind {
    case owner(DialogProviderCanonicalIngressKind)
    case assistant(DialogProviderCanonicalAssistantStreamKind)
    case playbackOnly
    case other
}

private func canonicalMemoryEventKind(rawEventCode: Int) -> DialogProviderCanonicalMemoryEventKind {
    switch rawEventCode {
    case DialogProviderSDKEventClassifier.asrInfo:
        return .owner(.asrInfo)
    case DialogProviderSDKEventClassifier.asrResponse:
        return .owner(.asrResponse)
    case DialogProviderSDKEventClassifier.asrEnded:
        return .owner(.asrEnded)
    case DialogProviderSDKEventClassifier.queryConfirmed:
        return .owner(.queryConfirmed)
    case DialogProviderSDKEventClassifier.chatResponse:
        return .assistant(.response)
    case DialogProviderSDKEventClassifier.chatEnded:
        return .assistant(.ended)
    case DialogProviderSDKEventClassifier.ttsSentenceStart,
         DialogProviderSDKEventClassifier.ttsSentenceEnd,
         DialogProviderSDKEventClassifier.ttsEnded:
        return .playbackOnly
    default:
        return .other
    }
}

private func freezeCanonicalMemoryPacket(
    rawEventCode: Int,
    data: Data,
    engineGeneration: UUID,
    capturedAt: Date,
    assistantState: inout DialogProviderCanonicalAssistantStreamState,
    router: DialogProviderCanonicalIngressRouter
) -> (result: DialogProviderCanonicalIngressResult?, assistantDelivered: Bool) {
    switch canonicalMemoryEventKind(rawEventCode: rawEventCode) {
    case .owner(let kind):
        return (
            router.freeze(
                kind: kind,
                data: data,
                engineGeneration: engineGeneration,
                capturedAt: capturedAt
            ),
            false
        )
    case .assistant(let kind):
        let metadata = DialogProviderEventMetadata(data: data)
        guard router.accepts(engineGeneration: engineGeneration),
              let event = assistantState.consume(
            kind: kind,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        ) else {
            return (
                router.freeze(
                    kind: .other,
                    data: data,
                    engineGeneration: engineGeneration,
                    capturedAt: capturedAt
                ),
                false
            )
        }
        let result = router.freezeAssistant(
            event,
            metadata: metadata,
            engineGeneration: engineGeneration
        )
        return (result, result != nil)
    case .playbackOnly, .other:
        return (
            router.freeze(
                kind: .other,
                data: data,
                engineGeneration: engineGeneration,
                capturedAt: capturedAt
            ),
            false
        )
    }
}

enum DialogTextReplyPlaybackError: LocalizedError, Equatable {
    case invalidText
    case sessionBusy
    case unavailable
    case directiveRejected(code: Int)

    var errorDescription: String? {
        switch self {
        case .invalidText:
            return "回响内容为空"
        case .sessionBusy:
            return "实时语音会话正在使用中"
        case .unavailable:
            return "火山实时语音暂不可用"
        case .directiveRejected:
            return "火山实时语音暂未接受本次播报"
        }
    }
}

private func isSameDialogAccountGeneration(_ lhs: AccountLease, _ rhs: AccountLease) -> Bool {
    lhs.subjectId == rhs.subjectId
        && lhs.vaultId == rhs.vaultId
        && lhs.generation == rhs.generation
        && lhs.generationId == rhs.generationId
        && lhs.authorityEpoch == rhs.authorityEpoch
}

/// Local SpeechEngine playback can only use a profile selected by the current
/// Echo binding. This prevents a role switch from falling back to whichever
/// profile the process-global VoiceCloneService happens to expose.
struct DialogEngineScopedTTSVoiceSelection: Equatable, Sendable {
    let bindingID: UUID
    let accountLease: AccountLease
    let contextKey: String
    let lifecycleGeneration: UInt64
    let voiceProfileId: String?

    init?(
        bindingID: UUID,
        accountLease: AccountLease,
        contextKey: String,
        lifecycleGeneration: UInt64,
        voiceProfileId: String?
    ) {
        let normalizedContextKey = contextKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedContextKey.isEmpty else { return nil }

        self.bindingID = bindingID
        self.accountLease = accountLease
        self.contextKey = normalizedContextKey
        self.lifecycleGeneration = lifecycleGeneration
        let normalizedProfileId = voiceProfileId?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.voiceProfileId = normalizedProfileId?.isEmpty == false ? normalizedProfileId : nil
    }

    func matches(bindingID: UUID, accountLease: AccountLease) -> Bool {
        self.bindingID == bindingID
            && isSameDialogAccountGeneration(self.accountLease, accountLease)
    }
}

struct DialogEngineScopedTTSVoiceSelectionStore {
    private(set) var selection: DialogEngineScopedTTSVoiceSelection?

    @discardableResult
    mutating func update(
        bindingID: UUID,
        accountLease: AccountLease,
        contextKey: String,
        lifecycleGeneration: UInt64,
        voiceProfileId: String?
    ) -> Bool {
        guard let candidate = DialogEngineScopedTTSVoiceSelection(
            bindingID: bindingID,
            accountLease: accountLease,
            contextKey: contextKey,
            lifecycleGeneration: lifecycleGeneration,
            voiceProfileId: voiceProfileId
        ) else {
            return false
        }

        if let selection,
           selection.bindingID == bindingID {
            guard isSameDialogAccountGeneration(selection.accountLease, accountLease),
                  candidate.lifecycleGeneration >= selection.lifecycleGeneration else {
                return false
            }
        }

        selection = candidate
        return true
    }

    func resolvedVoiceProfileId(
        bindingID: UUID,
        accountLease: AccountLease
    ) -> String? {
        guard let selection,
              selection.matches(bindingID: bindingID, accountLease: accountLease) else {
            return nil
        }
        return selection.voiceProfileId
    }

    @discardableResult
    mutating func clear(bindingID: UUID) -> Bool {
        guard selection?.bindingID == bindingID else { return false }
        selection = nil
        return true
    }

    mutating func clearAll() {
        selection = nil
    }
}

// This control is shared by the native Manager and local controlled-SDK tests.
// It owns only launch identity, not the SDK or the transcript lifecycle.
final class DialogVoiceLaunchExecutionControl {
    private(set) var operationID: UUID?
    private(set) var pendingID: String?
    private var isValid: (() -> Bool)?
    private(set) var startSubmitted = false

    func begin(operationID: UUID, pendingID: String?, isValid: (() -> Bool)?) {
        self.operationID = operationID
        self.pendingID = pendingID
        self.isValid = isValid
        startSubmitted = false
    }

    func permits(_ expectedOperationID: UUID) -> Bool {
        operationID == expectedOperationID && (isValid?() ?? true)
    }

    @discardableResult
    func markStartSubmitted(_ expectedOperationID: UUID) -> Bool {
        guard permits(expectedOperationID) else { return false }
        startSubmitted = true
        return true
    }

    // This is the Manager's actual preflight, ingress, and SDK submission sequence.
    // Keeping the final check here lets controlled SDK tests exercise that sequence.
    func performStartSubmission<Result>(
        operationID expectedOperationID: UUID,
        preflight: () -> Bool,
        installIngress: () -> Void,
        onRejected: () -> Void,
        send: () -> Result
    ) -> Result? {
        guard permits(expectedOperationID), preflight() else {
            onRejected()
            return nil
        }
        installIngress()
        guard preflight(), markStartSubmitted(expectedOperationID) else {
            onRejected()
            return nil
        }
        return send()
    }

    func acceptsSessionStarted(_ expectedOperationID: UUID) -> Bool {
        permits(expectedOperationID) && startSubmitted
    }

    @discardableResult
    func failStart(_ expectedOperationID: UUID) -> Bool {
        guard permits(expectedOperationID), startSubmitted else { return false }
        invalidate()
        return true
    }

    @discardableResult
    func cancel(pendingID expectedID: String?) -> Bool {
        guard let expectedID, pendingID == expectedID else { return false }
        invalidate()
        return true
    }

    @discardableResult
    func cancel(operationID expectedOperationID: UUID) -> Bool {
        guard operationID == expectedOperationID else { return false }
        invalidate()
        return true
    }

    @discardableResult
    func complete(pendingID expectedID: String) -> Bool {
        guard pendingID == expectedID, operationID != nil else { return false }
        pendingID = nil
        isValid = nil
        startSubmitted = false
        return true
    }

    func invalidate() {
        operationID = nil
        pendingID = nil
        isValid = nil
        startSubmitted = false
    }
}

#if (UI_QA_SIMULATOR || RELEASE_SCOPE_SIMULATOR) && targetEnvironment(simulator) && !LIVE_MANAGER_CONTROLLED_SDK

enum DialogEndReason {
    case manual
    case keyword(String)
    case silenceTimeout
    case serverEnded
}

protocol DialogEngineDelegate: AnyObject {
    func onDialogStarted()
    func onOrbAudioLevel(_ sample: DialogOrbAudioSample)
    func onASRResult(text: String, isFinal: Bool)
    func onTTSStarted(text: String)
    func onTTSPlaybackStarted()
    func onDelegatedPlaybackProgress(_ progress: DialogEngineDelegatedPlaybackProgress)
    func onTTSPlaybackInterruptedByUser()
    func onTTSFinished()
    func onChatStreaming(text: String)
    func onError(error: Error)
    func onDialogEnded(reason: DialogEndReason)
    func onCanonicalTranscriptMemberRegistered(_ member: NativeLiveCanonicalTranscriptMember)
    func onCanonicalTranscriptEvent(_ event: NativeLiveCanonicalTranscriptEvent)
    func makeCanonicalTranscriptDeliveryBinding() -> DialogCanonicalTranscriptDeliveryBinding
}

extension DialogEngineDelegate {
    func onOrbAudioLevel(_ sample: DialogOrbAudioSample) {}
    func onTTSPlaybackStarted() {}
    func onDelegatedPlaybackProgress(_ progress: DialogEngineDelegatedPlaybackProgress) {}
    func onTTSPlaybackInterruptedByUser() {}
    func onCanonicalTranscriptMemberRegistered(_ member: NativeLiveCanonicalTranscriptMember) {}
    func onCanonicalTranscriptEvent(_ event: NativeLiveCanonicalTranscriptEvent) {}
    func makeCanonicalTranscriptDeliveryBinding() -> DialogCanonicalTranscriptDeliveryBinding {
        DialogCanonicalTranscriptDeliveryBinding(deliver: { [weak self] member, event in
            if let member {
                self?.onCanonicalTranscriptMemberRegistered(member)
            }
            if let event {
                self?.onCanonicalTranscriptEvent(event)
            }
        })
    }
}

final class DialogEngineManager: NSObject {
    static let shared = DialogEngineManager()

    weak var delegate: DialogEngineDelegate?
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private var boundAccountLease: AccountLease?
    private var activeDialogAccountLease: AccountLease?
    private var boundBindingHandle: DialogEngineBindingHandle?
    private var activeDialogBindingHandle: DialogEngineBindingHandle?
    private(set) var isEngineReady = false
    private(set) var isDialogActive = false
    private(set) var isRecorderPaused = false
    private(set) var sessionLifetimePolicy: DialogSessionLifetimePolicy = .automatic
    private(set) var answerAuthority: DialogAnswerAuthority = .provider
    var currentTopic: String?
    var currentConfigurationIsProductionReady: Bool { false }
    private(set) var isLocalTTSPlaybackEnabled = true
    private(set) var usesTurnScopedKnowledgeContext = false
    private(set) var lastSubmittedTurnKnowledgeContextSource: String?
    private(set) var lastSubmittedTurnKnowledgeContextLength = 0
    private var scopedTTSVoiceSelectionStore = DialogEngineScopedTTSVoiceSelectionStore()
    private var externallyManagedAudioSessionLease: AudioOwnerLease?
    private let rawCanonicalIngressRouter = DialogProviderCanonicalIngressRouter()
    private var providerCanonicalAssistantStreamState =
        DialogProviderCanonicalAssistantStreamState()
    private var providerCanonicalAssistantIngressState =
        DialogProviderCanonicalAssistantStreamState()
    private let providerCanonicalMemoryIngressLock = NSLock()

    private override init() {
        super.init()
    }

    @discardableResult
    func bindAccountLease(
        _ accountLease: AccountLease,
        ownerId: UUID
    ) -> DialogEngineBindingHandle? {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        if let boundBindingHandle,
           boundBindingHandle.ownerId == ownerId,
           isSameDialogAccountGeneration(boundBindingHandle.accountLease, accountLease) {
            let rotatedHandle = DialogEngineBindingHandle(
                bindingId: boundBindingHandle.bindingId,
                ownerId: ownerId,
                accountLease: accountLease
            )
            self.boundBindingHandle = rotatedHandle
            boundAccountLease = accountLease
            if activeDialogBindingHandle?.bindingId == rotatedHandle.bindingId {
                activeDialogBindingHandle = rotatedHandle
                activeDialogAccountLease = accountLease
            }
            return rotatedHandle
        }

        if boundBindingHandle != nil {
            isDialogActive = false
            activeDialogAccountLease = nil
            activeDialogBindingHandle = nil
            scopedTTSVoiceSelectionStore.clearAll()
            delegate = nil
        }
        let handle = DialogEngineBindingHandle(
            bindingId: UUID(),
            ownerId: ownerId,
            accountLease: accountLease
        )
        boundBindingHandle = handle
        boundAccountLease = accountLease
        return handle
    }

    @discardableResult
    func unbindAccountLease(_ handle: DialogEngineBindingHandle) -> Bool {
        guard boundBindingHandle == handle else { return false }
        boundBindingHandle = nil
        boundAccountLease = nil
        activeDialogBindingHandle = nil
        activeDialogAccountLease = nil
        isDialogActive = false
        externallyManagedAudioSessionLease = nil
        _ = scopedTTSVoiceSelectionStore.clear(bindingID: handle.bindingId)
        delegate = nil
        return true
    }

    func isCurrentBinding(_ handle: DialogEngineBindingHandle?) -> Bool {
        guard let handle,
              boundBindingHandle == handle else { return false }
        return accountLeaseRuntime.validate(handle.accountLease, at: .runtime).allowed
    }

    /// Echo owns the session through AudioSessionCoordinator; the dialog engine must
    /// only reuse the exact active lease and never configure it a second time.
    @discardableResult
    func adoptExternallyManagedAudioSessionLease(_ lease: AudioOwnerLease) -> Bool {
        guard AudioSessionCoordinator.shared.isCurrentActiveLease(lease) else {
            externallyManagedAudioSessionLease = nil
            return false
        }
        externallyManagedAudioSessionLease = lease
        return true
    }

    private func isActiveAccountLeaseValid(at checkpoint: AccountLeaseCheckpoint) -> Bool {
        guard let accountLease = activeDialogAccountLease ?? boundAccountLease else {
            return false
        }
        return accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    func configure(runtimeConfig: RealtimeVoiceRuntimeConfig) -> Bool { !runtimeConfig.isBlocked }
    @discardableResult
    func interruptAI() -> Bool { false }
    @discardableResult
    func setLocalTTSPlaybackEnabled(_ enabled: Bool) -> Bool {
        isLocalTTSPlaybackEnabled = enabled
        return true
    }

    @discardableResult
    func setLocalTTSVoiceSelection(
        voiceProfileId: String?,
        contextKey: String,
        lifecycleGeneration: UInt64,
        for handle: DialogEngineBindingHandle
    ) -> Bool {
        guard isCurrentBinding(handle) else { return false }
        return scopedTTSVoiceSelectionStore.update(
            bindingID: handle.bindingId,
            accountLease: handle.accountLease,
            contextKey: contextKey,
            lifecycleGeneration: lifecycleGeneration,
            voiceProfileId: voiceProfileId
        )
    }

    func setup() {
        guard isActiveAccountLeaseValid(at: .request) else { return }
        isEngineReady = true
    }

    func startDialog(
        sendsGreeting: Bool = true,
        usesTurnScopedKnowledgeContext: Bool = false,
        lifetimePolicy: DialogSessionLifetimePolicy = .automatic,
        answerAuthority: DialogAnswerAuthority = .provider,
        voiceLaunchID: String? = nil,
        voiceLaunchIsValid: (() -> Bool)? = nil
    ) {
        guard isActiveAccountLeaseValid(at: .request),
              voiceLaunchIsValid?() ?? true,
              let accountLease = boundAccountLease,
              let bindingHandle = boundBindingHandle else { return }
        activeDialogAccountLease = accountLease
        activeDialogBindingHandle = bindingHandle
        self.usesTurnScopedKnowledgeContext = usesTurnScopedKnowledgeContext
        sessionLifetimePolicy = lifetimePolicy
        self.answerAuthority = answerAuthority
        isRecorderPaused = false
        recordUIQAPromptSnapshot()
        isDialogActive = true
        if isActiveAccountLeaseValid(at: .runtime) {
            delegate?.onDialogStarted()
        }
    }

    func cancelPendingVoiceLaunch(id: String?) {
        guard id != nil, !isDialogActive else { return }
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
    }

    func completeVoiceLaunch(id: String) {}

    @discardableResult
    func startTextReplyPlayback(
        text: String,
        onStarted: @escaping () -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            completion(.failure(DialogTextReplyPlaybackError.invalidText))
            return false
        }
        guard !isDialogActive else {
            completion(.failure(DialogTextReplyPlaybackError.sessionBusy))
            return false
        }
        onStarted()
        completion(.success(()))
        return true
    }

    func cancelTextReplyPlayback() {}

    @discardableResult
    func pauseRecorder() -> Bool {
        guard isDialogActive else { return false }
        isRecorderPaused = true
        return true
    }

    @discardableResult
    func resumeRecorder() -> Bool {
        resumeRecorderOutcome().isSuccess
    }

    @discardableResult
    func resumeRecorderOutcome() -> DialogRecorderResumeOutcome {
        guard isDialogActive else { return .sessionInactive }
        guard isRecorderPaused else { return .alreadyRunning }
        isRecorderPaused = false
        return .directiveSent
    }

    @discardableResult
    func submitTurnKnowledgeContext(
        _ content: String,
        traceID: String?,
        source: String
    ) -> Bool {
        guard isDialogActive,
              isActiveAccountLeaseValid(at: .runtime) else { return false }
        lastSubmittedTurnKnowledgeContextSource = source
        lastSubmittedTurnKnowledgeContextLength = content.utf8.count
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "uiQATurnKnowledgeContextSubmitted",
            states: ["source": source],
            counts: ["contentBytes": content.utf8.count],
            correlations: ["traceID": PrivacySafeDiagnostics.correlationHash(traceID)]
        )
        return true
    }

    @discardableResult
    func observeLiveContextASR(_ text: String, isFinal: Bool) {}
    func updateLiveContextAfterPlayback() {}

    func submitLiveFarewell(_ content: String, bindingHandle: DialogEngineBindingHandle?,
        completion: @escaping () -> Void) -> Bool {
        // The UI-only simulator has no provider. Native controlled-SDK tests
        // exercise the production implementation instead of faking success here.
        return false
    }

    @discardableResult
    func submitLiveAnswerText(
        _ content: String,
        traceID: String?,
        source: String
    ) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDialogActive,
              isActiveAccountLeaseValid(at: .runtime),
              answerAuthority == .dreamJourneyBackend,
              isLocalTTSPlaybackEnabled,
              !normalized.isEmpty else {
            return false
        }
        delegate?.onTTSStarted(text: normalized)
        let replyID = "uiqa-\(UUID().uuidString)"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.onDelegatedPlaybackProgress(.providerAccepted(replyID: replyID))
            self.delegate?.onDelegatedPlaybackProgress(.audioStarted(replyID: replyID))
            self.delegate?.onDelegatedPlaybackProgress(.synthesisEnded(replyID: replyID))
            self.delegate?.onDelegatedPlaybackProgress(.audioFinished(replyID: replyID))
        }
        return true
    }

    #if DEBUG
    func installCanonicalIngressForTesting(
        engineGeneration: UUID,
        dialogOperationID: UUID,
        delegate: DialogEngineDelegate
    ) {
        providerCanonicalMemoryIngressLock.lock()
        providerCanonicalAssistantStreamState.reset()
        providerCanonicalAssistantIngressState.reset()
        let deliveryBinding = delegate.makeCanonicalTranscriptDeliveryBinding()
        rawCanonicalIngressRouter.install(
            engineGeneration: engineGeneration,
            dialogOperationID: dialogOperationID,
            reserve: deliveryBinding.reserve,
            deliver: deliveryBinding.deliver
        )
        providerCanonicalMemoryIngressLock.unlock()
    }

    @discardableResult
    func enqueueCanonicalProviderMessageForTesting(
        kind: DialogProviderCanonicalIngressKind,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> DialogProviderCanonicalIngressResult? {
        rawCanonicalIngressRouter.freeze(
            kind: kind,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        )
    }

    @discardableResult
    func enqueueCanonicalRawProviderMessageForTesting(
        rawEventCode: Int,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> DialogProviderCanonicalIngressResult? {
        providerCanonicalMemoryIngressLock.lock()
        defer { providerCanonicalMemoryIngressLock.unlock() }
        return freezeCanonicalMemoryPacket(
            rawEventCode: rawEventCode,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt,
            assistantState: &providerCanonicalAssistantIngressState,
            router: rawCanonicalIngressRouter
        ).result
    }

    func closeCanonicalIngressForTesting(dialogOperationID: UUID? = nil) {
        providerCanonicalMemoryIngressLock.lock()
        if rawCanonicalIngressRouter.close(expectedDialogOperationID: dialogOperationID) {
            providerCanonicalAssistantStreamState.reset()
            providerCanonicalAssistantIngressState.reset()
        }
        providerCanonicalMemoryIngressLock.unlock()
    }

    func stopCanonicalIngressForTesting(
        engineGeneration: UUID,
        dialogOperationID: UUID
    ) {
        providerCanonicalMemoryIngressLock.lock()
        _ = rawCanonicalIngressRouter.sealActiveOwnerForStop(
            engineGeneration: engineGeneration
        )
        rawCanonicalIngressRouter.close(expectedDialogOperationID: dialogOperationID)
        providerCanonicalAssistantStreamState.reset()
        providerCanonicalAssistantIngressState.reset()
        providerCanonicalMemoryIngressLock.unlock()
    }

    func setCanonicalIngressDeliverySchedulerForTesting(
        _ scheduler: @escaping DialogProviderCanonicalIngressRouter.DeliveryScheduler
    ) {
        rawCanonicalIngressRouter.setDeliverySchedulerForTesting(scheduler)
    }

    @discardableResult
    func enqueueCanonicalAssistantForTesting(
        replyID: String,
        text: String,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> Bool {
        rawCanonicalIngressRouter.deliverAssistantForTesting(
            replyID: replyID,
            text: text,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        )
    }

    @discardableResult
    func enqueueCanonicalAssistantProviderMessageForTesting(
        kind: DialogProviderCanonicalAssistantStreamKind,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> NativeLiveCanonicalTranscriptEvent? {
        providerCanonicalMemoryIngressLock.lock()
        defer { providerCanonicalMemoryIngressLock.unlock() }
        return deliverCanonicalAssistantStreamPacket(
            state: &providerCanonicalAssistantStreamState,
            router: rawCanonicalIngressRouter,
            kind: kind,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        )
    }
    #endif

    func stopDialog(onInputSealed: (() -> Void)? = nil) {
        // UI-QA Manager has no native engine; preserve the same close boundary.
        onInputSealed?()
        guard isDialogActive else { return }
        let shouldDeliver = isActiveAccountLeaseValid(at: .runtime)
        isDialogActive = false
        isRecorderPaused = false
        activeDialogBindingHandle = nil
        activeDialogAccountLease = nil
        if shouldDeliver {
            delegate?.onDialogEnded(reason: .manual)
        }
    }

    func destroyEngine() {
        isEngineReady = false
        isDialogActive = false
        isRecorderPaused = false
        sessionLifetimePolicy = .automatic
        answerAuthority = .provider
        activeDialogBindingHandle = nil
        activeDialogAccountLease = nil
        usesTurnScopedKnowledgeContext = false
        externallyManagedAudioSessionLease = nil
        delegate = nil
    }

    private func recordUIQAPromptSnapshot() {
        #if DEBUG || UI_QA_SIMULATOR
        var prompt = "【UI QA 回响 Prompt】\n你是寻梦环游 AI 助手，不是真人或任何家庭成员本人。请以温和、自然的方式回应长辈。"
        let context = DigitalHumanContextStore.shared.current
        prompt += buildDigitalHumanModePolicy(context: context)
        let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot()
        let archiveContext = archiveSnapshot.promptSection
        // Legacy UIQA archive smoke still inspects this synthetic prompt. The production
        // engine suppresses the same startup section when turn-scoped RAG is enabled.
        if shouldExposePersonalContext(for: context), !archiveContext.isEmpty {
            prompt += archiveContext
        }

        DialogPromptDebugRecorder.record(prompt: prompt)
        let snapshot = DialogPromptDebugRecorder.lastSnapshot
        PrivacySafeDiagnostics.log(
            subsystem: "UI_QA",
            event: "echoArchivePromptRecorded",
            states: [
                "containsArchiveContext": snapshot?.containsArchiveContext == true ? "true" : "false"
            ],
            counts: ["availableItemCount": archiveSnapshot.availableItemCount]
        )
        #endif
    }
}

enum DialogEngineError: LocalizedError {
    case productionConfigurationMissing
    case initFailed(code: Int)
    case startFailed(code: Int)
    case audioSessionFailed
    case sdkError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .productionConfigurationMissing:
            return "实时语音凭据代理尚未开放，当前可继续使用文字回响"
        case .initFailed(let code):
            return "语音引擎初始化失败 (错误码: \(code))"
        case .startFailed(let code):
            return "语音对话启动失败 (错误码: \(code))"
        case .audioSessionFailed:
            return "音频配置失败，请重试"
        case .sdkError(_, let message):
            return "语音服务异常: \(message)"
        }
    }
}
#else
import Foundation
import AVFoundation
import CocoaLumberjack
// Only the vendor boundary is controlled. The native Manager below is unchanged
// in this build, including setup, delegate proxy, operation and cleanup code.
// This is not a wire/SDK implementation and cannot establish Provider acceptance.
#if LIVE_MANAGER_CONTROLLED_SDK
#if !DEBUG || !targetEnvironment(simulator)
#error("LIVE_MANAGER_CONTROLLED_SDK is restricted to Debug Simulator tests")
#endif
struct MICControlledSDKValue: Equatable {
    let rawValue: Int
}
typealias SEMessageType = MICControlledSDKValue
protocol SpeechEngineDelegate: AnyObject {
    func onMessage(with type: SEMessageType, andData data: Data)
}
let SEDecoderAudioData = MICControlledSDKValue(rawValue: 3100)
let SEDialogWorkModeDefault = MICControlledSDKValue(rawValue: 0)
let SEDialogWorkModeDelegateChatTtsText = MICControlledSDKValue(rawValue: 1)
let SEDirectiveDialogUseClientTriggerTts = MICControlledSDKValue(rawValue: 4000)
let SEDirectiveEventChatRagText = MICControlledSDKValue(rawValue: 3009)
let SEDirectiveEventClientInterrupt = MICControlledSDKValue(rawValue: 3010)
let SEDirectiveEventSayHello = MICControlledSDKValue(rawValue: 3006)
let SEDirectivePauseRecorder = MICControlledSDKValue(rawValue: 1502)
let SEDirectiveResumeRecorder = MICControlledSDKValue(rawValue: 1503)
let SEDirectiveEventUpdateConfig = MICControlledSDKValue(rawValue: 3011)
let SEEventConfigUpdated = MICControlledSDKValue(rawValue: 3022)
let SEDirectiveStartEngine = MICControlledSDKValue(rawValue: 1000)
let SEDirectiveSyncStopEngine = MICControlledSDKValue(rawValue: 2001)
let SEEngineError = MICControlledSDKValue(rawValue: 1003)
let SEEngineStart = MICControlledSDKValue(rawValue: 1001)
let SEEngineStop = MICControlledSDKValue(rawValue: 1002)
let SEEventASREnded = MICControlledSDKValue(rawValue: 3014)
let SEEventASRInfo = MICControlledSDKValue(rawValue: 3012)
let SEEventASRResponse = MICControlledSDKValue(rawValue: 3013)
let SEEventChatEnded = MICControlledSDKValue(rawValue: 3016)
let SEEventChatResponse = MICControlledSDKValue(rawValue: 3015)
let SEEventChatTextQueryConfirmed = MICControlledSDKValue(rawValue: 3021)
let SEEventConnectionFailed = MICControlledSDKValue(rawValue: 3001)
let SEEventConnectionFinished = MICControlledSDKValue(rawValue: 3002)
let SEEventConnectionStarted = MICControlledSDKValue(rawValue: 3000)
let SEEventSessionCanceled = MICControlledSDKValue(rawValue: 3004)
let SEEventSessionFailed = MICControlledSDKValue(rawValue: 3006)
let SEEventSessionFinished = MICControlledSDKValue(rawValue: 3005)
let SEEventSessionStarted = MICControlledSDKValue(rawValue: 3003)
let SEEventTTSEnded = MICControlledSDKValue(rawValue: 3011)
let SEEventTTSResponse = MICControlledSDKValue(rawValue: 3010)
let SEEventTTSSentenceEnd = MICControlledSDKValue(rawValue: 3009)
let SEEventTTSSentenceStart = MICControlledSDKValue(rawValue: 3008)
let SENoError = MICControlledSDKValue(rawValue: 0)
let SERecorderAudioData = MICControlledSDKValue(rawValue: 3017)
let SEPlayerAudioData = MICControlledSDKValue(rawValue: 3018)
let SEPlayerFinishPlayAudio = MICControlledSDKValue(rawValue: 3020)
let SEPlayerStartPlayAudio = MICControlledSDKValue(rawValue: 3019)
let SE_DIALOG_ENGINE = "SE_DIALOG_ENGINE"
let SE_LOG_LEVEL_WARN = "SE_LOG_LEVEL_WARN"
let SE_PARAMS_KEY_APP_ID_STRING = "SE_PARAMS_KEY_APP_ID_STRING"
let SE_PARAMS_KEY_APP_KEY_STRING = "SE_PARAMS_KEY_APP_KEY_STRING"
let SE_PARAMS_KEY_APP_TOKEN_STRING = "SE_PARAMS_KEY_APP_TOKEN_STRING"
let SE_PARAMS_KEY_DIALOG_ADDRESS_STRING = "SE_PARAMS_KEY_DIALOG_ADDRESS_STRING"
let SE_PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL = "SE_PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL"
let SE_PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL = "SE_PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL"
let SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL = "SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL"
let SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL = "SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL"
let SE_PARAMS_KEY_DIALOG_URI_STRING = "SE_PARAMS_KEY_DIALOG_URI_STRING"
let SE_PARAMS_KEY_DIALOG_WORK_MODE_INT = "SE_PARAMS_KEY_DIALOG_WORK_MODE_INT"
let SE_PARAMS_KEY_ENABLE_AEC_BOOL = "SE_PARAMS_KEY_ENABLE_AEC_BOOL"
let SE_PARAMS_KEY_ENABLE_GET_VOLUME_BOOL = "SE_PARAMS_KEY_ENABLE_GET_VOLUME_BOOL"
let SE_PARAMS_KEY_ENABLE_WS_RECONNECT_BOOL = "SE_PARAMS_KEY_ENABLE_WS_RECONNECT_BOOL"
let SE_PARAMS_KEY_ENGINE_NAME_STRING = "SE_PARAMS_KEY_ENGINE_NAME_STRING"
let SE_PARAMS_KEY_FULLLINK_DISABLE_TTS_BOOL = "SE_PARAMS_KEY_FULLLINK_DISABLE_TTS_BOOL"
let SE_PARAMS_KEY_LOG_LEVEL_STRING = "SE_PARAMS_KEY_LOG_LEVEL_STRING"
let SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL = "SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL"
let SE_PARAMS_KEY_RECORDER_TYPE_STRING = "SE_PARAMS_KEY_RECORDER_TYPE_STRING"
let SE_PARAMS_KEY_REQUEST_HEADERS_STRING = "SE_PARAMS_KEY_REQUEST_HEADERS_STRING"
let SE_PARAMS_KEY_RESET_AUDIOSESSION_BOOL = "SE_PARAMS_KEY_RESET_AUDIOSESSION_BOOL"
let SE_PARAMS_KEY_RESOURCE_ID_STRING = "SE_PARAMS_KEY_RESOURCE_ID_STRING"
let SE_PARAMS_KEY_RESTART_AUDIOSESSION_BOOL = "SE_PARAMS_KEY_RESTART_AUDIOSESSION_BOOL"
let SE_PARAMS_KEY_RESUME_OTHERS_INTERRUPTED_PLAYBACK_BOOL = "SE_PARAMS_KEY_RESUME_OTHERS_INTERRUPTED_PLAYBACK_BOOL"
let SE_PARAMS_KEY_UID_STRING = "SE_PARAMS_KEY_UID_STRING"
let SE_RECORDER_TYPE_RECORDER = "SE_RECORDER_TYPE_RECORDER"
final class SpeechEngine {
    static var instances: [SpeechEngine] = []
    static var onInitialize: (() -> Void)?
    static var onSyncStop: (() -> Void)?
    static var initializationResult = SENoError
    static var startResult = SENoError
    static var sayHelloResult = SENoError
    static var createResult = true
    static func prepareEnvironment() {}
    static func resetControlledBoundary() {
        instances = []; onInitialize = nil; onSyncStop = nil
        initializationResult = SENoError; startResult = SENoError; sayHelloResult = SENoError; createResult = true
    }
    private var callback: SpeechEngineDelegate?
    private(set) var directives: [(MICControlledSDKValue, String?)] = []
    private(set) var parameters: [String: String] = [:]
    private(set) var destroyCount = 0
    init() { Self.instances.append(self) }
    func createEngine(with delegate: SpeechEngineDelegate) -> Bool {
        callback = delegate
        return Self.createResult
    }
    func setStringParam(_ value: String, forKey key: String) { parameters[key] = value }
    func setIntParam<T: BinaryInteger>(_ value: T, forKey key: String) { parameters[key] = String(value) }
    func setBoolParam(_ value: Bool, forKey key: String) { parameters[key] = String(value) }
    func initEngine() -> MICControlledSDKValue {
        Self.onInitialize?()
        return Self.initializationResult
    }
    @discardableResult
    func send(_ directive: MICControlledSDKValue, data: String? = nil) -> MICControlledSDKValue {
        directives.append((directive, data))
        if directive == SEDirectiveSyncStopEngine { Self.onSyncStop?() }
        if directive == SEDirectiveEventSayHello { return Self.sayHelloResult }
        return directive == SEDirectiveStartEngine ? Self.startResult : SENoError
    }
    func destroy() { destroyCount += 1 }
    // Retain the old proxy to exercise late callbacks from a destroyed engine.
    func emit(_ type: SEMessageType, data: Data = Data("{}".utf8)) {
        callback?.onMessage(with: type, andData: data)
    }
    func count(_ directive: MICControlledSDKValue) -> Int {
        directives.filter { $0.0 == directive }.count
    }
}
#else
import SpeechEngineToB
#endif


#if DEBUG && !LIVE_MANAGER_CONTROLLED_SDK
private final class DialogT06ControlledWebSocketClient: NSObject, SpeechWsClientProtocol {
    private var listener: SpeechWsListenerProtocol?
    private var didRecordTerminalEvidence = false
    private var observedFrameCount = 0

    func setup(withListener listener: SpeechWsListenerProtocol) -> Bool {
        self.listener = listener
        PrivacySafeDiagnostics.log(
            subsystem: "T06SDKCapture",
            event: "controlledUpstreamReady",
            states: ["sdkVersion": "0.0.14.6.1-bugfix"]
        )
        return true
    }

    func startConnection(_ config: SpeechWsConnectionConfig) -> Bool {
        PrivacySafeDiagnostics.log(
            subsystem: "T06SDKCapture",
            event: "controlledUpstreamConnected",
            states: ["transport": "customWsClient"]
        )
        DispatchQueue.main.async { [weak self] in
            self?.listener?.onConnected("t06-controlled-upstream")
        }
        return true
    }

    func send(_ data: Data) -> Bool {
        observedFrameCount += 1
        guard !didRecordTerminalEvidence else { return true }
        guard let observation = DialogT06SDKFrameInspector.inspect(
                frame: data,
                expectedRoleText: DialogT06DiagnosticMode.syntheticProviderRoleText,
                expectedProviderContextHash: DialogT06DiagnosticMode.providerContextHash,
                expectedFieldPath: DialogT06DiagnosticMode.expectedRolePath
              ) else {
            if observedFrameCount <= 4 {
                let header = data.prefix(8).map { String(format: "%02x", $0) }.joined()
                PrivacySafeDiagnostics.log(
                    subsystem: "T06SDKCapture",
                    event: "sdkFrameObserved",
                    states: ["header": header.isEmpty ? "none" : header],
                    counts: [
                        "frameIndex": observedFrameCount,
                        "frameBytes": data.count,
                    ]
                )
            }
            return true
        }
        didRecordTerminalEvidence = true
        PrivacySafeDiagnostics.log(
            subsystem: "T06SDKCapture",
            event: "upstreamStartSessionObserved",
            states: [
                "event": String(observation.event),
                "fieldPath": observation.fieldPath,
                "roleHash": observation.roleHash,
                "providerContextHash": observation.providerContextHash,
                "modelFieldPresent": observation.modelFieldPresent ? "true" : "false",
                "legacyDialogWrapper": observation.hasLegacyDialogWrapper ? "true" : "false",
                "roleMatch": observation.roleMatchesExpected ? "true" : "false",
                "hashMatch": observation.hashMatchesExpected ? "true" : "false",
                "pathMatch": observation.fieldPathMatchesExpected ? "true" : "false",
                "contractMatch": observation.contractMatches ? "true" : "false",
            ],
            counts: ["roleBytes": observation.roleByteCount]
        )
        return true
    }

    func stopConnection() -> Bool {
        listener = nil
        return true
    }
}
#endif

#if DEBUG
extension DialogEngineManager {
    func installCanonicalIngressForTesting(
        engineGeneration: UUID,
        dialogOperationID: UUID,
        delegate: DialogEngineDelegate
    ) {
        providerCanonicalMemoryIngressLock.lock()
        providerCanonicalAssistantStreamState.reset()
        providerCanonicalAssistantIngressState.reset()
        let deliveryBinding = delegate.makeCanonicalTranscriptDeliveryBinding()
        rawCanonicalIngressRouter.install(
            engineGeneration: engineGeneration,
            dialogOperationID: dialogOperationID,
            reserve: deliveryBinding.reserve,
            deliver: deliveryBinding.deliver
        )
        providerCanonicalMemoryIngressLock.unlock()
    }

    @discardableResult
    func enqueueCanonicalProviderMessageForTesting(
        kind: DialogProviderCanonicalIngressKind,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> DialogProviderCanonicalIngressResult? {
        rawCanonicalIngressRouter.freeze(
            kind: kind,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        )
    }

    @discardableResult
    func enqueueCanonicalRawProviderMessageForTesting(
        rawEventCode: Int,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> DialogProviderCanonicalIngressResult? {
        providerCanonicalMemoryIngressLock.lock()
        defer { providerCanonicalMemoryIngressLock.unlock() }
        return freezeCanonicalMemoryPacket(
            rawEventCode: rawEventCode,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt,
            assistantState: &providerCanonicalAssistantIngressState,
            router: rawCanonicalIngressRouter
        ).result
    }

    func closeCanonicalIngressForTesting(dialogOperationID: UUID? = nil) {
        providerCanonicalMemoryIngressLock.lock()
        if rawCanonicalIngressRouter.close(expectedDialogOperationID: dialogOperationID) {
            providerCanonicalAssistantStreamState.reset()
            providerCanonicalAssistantIngressState.reset()
        }
        providerCanonicalMemoryIngressLock.unlock()
    }

    func stopCanonicalIngressForTesting(
        engineGeneration: UUID,
        dialogOperationID: UUID
    ) {
        providerCanonicalMemoryIngressLock.lock()
        _ = rawCanonicalIngressRouter.sealActiveOwnerForStop(
            engineGeneration: engineGeneration
        )
        rawCanonicalIngressRouter.close(expectedDialogOperationID: dialogOperationID)
        providerCanonicalAssistantStreamState.reset()
        providerCanonicalAssistantIngressState.reset()
        providerCanonicalMemoryIngressLock.unlock()
    }

    func setCanonicalIngressDeliverySchedulerForTesting(
        _ scheduler: @escaping DialogProviderCanonicalIngressRouter.DeliveryScheduler
    ) {
        rawCanonicalIngressRouter.setDeliverySchedulerForTesting(scheduler)
    }

    @discardableResult
    func enqueueCanonicalAssistantForTesting(
        replyID: String,
        text: String,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> Bool {
        rawCanonicalIngressRouter.deliverAssistantForTesting(
            replyID: replyID,
            text: text,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        )
    }

    @discardableResult
    func enqueueCanonicalAssistantProviderMessageForTesting(
        kind: DialogProviderCanonicalAssistantStreamKind,
        data: Data,
        engineGeneration: UUID,
        capturedAt: Date = Date()
    ) -> NativeLiveCanonicalTranscriptEvent? {
        providerCanonicalMemoryIngressLock.lock()
        defer { providerCanonicalMemoryIngressLock.unlock() }
        return deliverCanonicalAssistantStreamPacket(
            state: &providerCanonicalAssistantStreamState,
            router: rawCanonicalIngressRouter,
            kind: kind,
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: capturedAt
        )
    }
}
#endif

private final class DialogPCMPlaybackController: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var completion: ((Bool) -> Void)?

    @discardableResult
    func play(
        pcmData: Data,
        sampleRate: UInt32 = 24_000,
        onStarted: () -> Void,
        completion: @escaping (Bool) -> Void
    ) -> Bool {
        stop()
        guard let waveData = DialogPCM16WaveEncoder.encode(
            pcmData: pcmData,
            sampleRate: sampleRate
        ) else {
            return false
        }

        do {
            let player = try AVAudioPlayer(data: waveData)
            player.delegate = self
            player.volume = 1
            guard player.prepareToPlay(), player.play() else {
                return false
            }
            self.player = player
            self.completion = completion
            onStarted()
            return true
        } catch {
            return false
        }
    }

    func stop() {
        player?.stop()
        player?.delegate = nil
        player = nil
        completion = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === self.player else { return }
        let completion = completion
        stop()
        completion?(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === self.player else { return }
        let completion = completion
        stop()
        completion?(false)
    }
}

// MARK: - 对话结束原因

enum DialogEndReason {
    case manual            // 用户手动停止
    case keyword(String)   // 识别到结束关键词
    case silenceTimeout    // 静音超时
    case serverEnded       // 服务端结束
}

// MARK: - DialogEngineDelegate 协议

/// Dialog 引擎对外回调协议
protocol DialogEngineDelegate: AnyObject {
    func onDialogStarted()
    func onOrbAudioLevel(_ sample: DialogOrbAudioSample)
    func onASRResult(text: String, isFinal: Bool)
    func onTTSStarted(text: String)
    func onTTSPlaybackStarted()
    func onDelegatedPlaybackProgress(_ progress: DialogEngineDelegatedPlaybackProgress)
    func onTTSPlaybackInterruptedByUser()
    func onTTSFinished()
    func onChatStreaming(text: String)
    func onError(error: Error)
    func onDialogEnded(reason: DialogEndReason)
    func onCanonicalTranscriptMemberRegistered(_ member: NativeLiveCanonicalTranscriptMember)
    func onCanonicalTranscriptEvent(_ event: NativeLiveCanonicalTranscriptEvent)
    func makeCanonicalTranscriptDeliveryBinding() -> DialogCanonicalTranscriptDeliveryBinding
}

extension DialogEngineDelegate {
    func onOrbAudioLevel(_ sample: DialogOrbAudioSample) {}
    func onTTSPlaybackStarted() {}
    func onDelegatedPlaybackProgress(_ progress: DialogEngineDelegatedPlaybackProgress) {}
    func onTTSPlaybackInterruptedByUser() {}
    func onCanonicalTranscriptMemberRegistered(_ member: NativeLiveCanonicalTranscriptMember) {}
    func onCanonicalTranscriptEvent(_ event: NativeLiveCanonicalTranscriptEvent) {}
    func makeCanonicalTranscriptDeliveryBinding() -> DialogCanonicalTranscriptDeliveryBinding {
        DialogCanonicalTranscriptDeliveryBinding { [weak self] member, event in
            if let member {
                self?.onCanonicalTranscriptMemberRegistered(member)
            }
            if let event {
                self?.onCanonicalTranscriptEvent(event)
            }
        }
    }
}

private final class DialogEngineProviderDelegateProxy: NSObject, SpeechEngineDelegate {
    weak var owner: DialogEngineManager?
    let engineGeneration: UUID

    init(owner: DialogEngineManager, engineGeneration: UUID) {
        self.owner = owner
        self.engineGeneration = engineGeneration
    }

    func onMessage(with type: SEMessageType, andData data: Data) {
        owner?.enqueueProviderMessage(
            type: type,
            data: data,
            engineGeneration: engineGeneration
        )
    }
}

private struct DialogEngineProviderCallbackContext {
    let engineGeneration: UUID
    let dialogOperationId: UUID
    let bindingHandle: DialogEngineBindingHandle
    let delegateIdentity: ObjectIdentifier
}

private struct DialogLiveFarewellRequest {
    let context: DialogEngineProviderCallbackContext
    let excludedReplyIDs: Set<String>
    let completion: () -> Void
    var replyID: String?
    var observedAudio = false
    var pcm = DialogProviderPCMDrainVerifier()
    var player = DialogProviderReplyPlaybackState()
}

private struct DialogEngineFrozenProviderMessage {
    let type: SEMessageType
    let data: Data
    let engineGeneration: UUID
    let callbackOrdinal: UInt64
    let metadata: DialogProviderEventMetadata
    let canonicalOwnerDeliveredAtIngress: Bool
    let canonicalAssistantDeliveredAtIngress: Bool
}

private struct DialogEngineRawCanonicalIngressBinding {
    let engineGeneration: UUID
    let dialogOperationID: UUID
    let deliver: (
        NativeLiveCanonicalTranscriptMember?,
        NativeLiveCanonicalTranscriptEvent?
    ) -> Void
}

private struct DialogEngineTextReplyPlayback {
    let id: UUID
    let text: String
    let onStarted: () -> Void
    let completion: (Result<Void, Error>) -> Void
}

private enum DelegatedTTSEventPhase {
    case started
    case sentenceEnded
    case streamEnded
}

// MARK: - DialogEngineManager

/// Dialog 语音对话引擎管理器 - 直接封装火山引擎 SpeechEngineToB SDK
/// 提供语音对话的启动、停止、生命周期管理
final class DialogEngineManager: NSObject {

    private let orbAudioRelay = DialogOrbAudioRelay()

    // MARK: - Singleton

    static let shared = DialogEngineManager()

    // MARK: - Properties

    weak var delegate: DialogEngineDelegate?
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private var boundAccountLease: AccountLease?
    private var engineAccountLease: AccountLease?
    private var activeDialogAccountLease: AccountLease?
    private var boundBindingHandle: DialogEngineBindingHandle?
    private var engineBindingId: UUID?
    private var activeDialogBindingHandle: DialogEngineBindingHandle?
    private var activeDialogOperationId: UUID?
    private var providerSessionOperationId: UUID?
    private var pendingVoiceLaunchID: String?
    #if LIVE_MANAGER_CONTROLLED_SDK
    private(set) var controlledCallbackDrainForTesting = 0
    var controlledCanonicalIngressOpenForTesting: Bool {
        engineCallbackGeneration.map { rawCanonicalIngressRouter.accepts(engineGeneration: $0) } ?? false
    }
    #endif
    private let voiceLaunchControl = DialogVoiceLaunchExecutionControl()
    private var pendingVoiceStartSubmitted = false
    private var engineCallbackGeneration: UUID?
    private var engineDelegateProxy: DialogEngineProviderDelegateProxy?
    private var requiresEngineRecreationBeforeNextDialog = false
    private var scopedTTSVoiceSelectionStore = DialogEngineScopedTTSVoiceSelectionStore()
    private var externallyManagedAudioSessionLease: AudioOwnerLease?
    private var pendingTextReplyPlayback: DialogEngineTextReplyPlayback?
    private var liveFarewellRequest: DialogLiveFarewellRequest?
    private var observedLiveReplyIDs = Set<String>()
    // Read/write only under providerCanonicalMemoryIngressLock.
    private var farewellIngressScope: (generation: UUID, excludedReplyIDs: Set<String>)?
    private var textReplyPlaybackFallbackWorkItem: DispatchWorkItem?
    private var engineAnswerAuthority: DialogAnswerAuthority?
    private var engineUsesDelegatedLivePlayback = false
    private var isDelegatedClientTTSRouteSelected = false
    private var delegatedClientTTSReplyIDs = Set<String>()
    private var delegatedServerTTSReplyIDs = Set<String>()
    private var delegatedClientPlaybackReplyID: String?
    private var isDelegatedClientTTSSubmissionPending = false
    private var delegatedClientPlaybackState = DialogEngineDelegatedPlaybackState()
    private var delegatedClientPlaybackAudioActivityObserved = false
    private var delegatedClientDecodedPCM = Data()
    private let delegatedClientPCMPlayer = DialogPCMPlaybackController()
    private var runtimeSystemRole: String?
    private var runtimeSpeakingStyle: String?
    private var runtimeFormalMemorySnapshot: [String: Any]?
    private var runtimeContextUpdateTicketID: String?
    private var liveContextUpdates = LiveContextUpdateState()
    private var liveContextReadControl: LiveContextReadControl?
    private var liveContextClient = DreamJourneyBackendClient.shared
    private var runtimeProviderRoleText: String?
    private var runtimeProviderContextHash: String?
    private var runtimeProjectionCheckpoint: String?
    private var runtimeMemoryRevision: Int?
    private var runtimeProductSessionID: String?
    private var liveStartSubmittedAt: Date?
    private var liveStartDirectiveReturnCode: Int?
    private var liveFirstResponseObserved = false
    private var providerTurnCorrelation = DialogProviderTurnCorrelationState()
    private var providerReplyPlaybackState = DialogProviderReplyPlaybackState()
    private var providerPCMDrain = DialogProviderPCMDrainVerifier()
    private var providerInterruptionState = DialogProviderInterruptionState()
    private var providerActiveChatReplyID: String?
    private var providerCanonicalAssistantTextState = DialogProviderCanonicalReplyTextState()
    private var providerCanonicalAssistantStreamState =
        DialogProviderCanonicalAssistantStreamState()
    private var providerCanonicalAssistantIngressState =
        DialogProviderCanonicalAssistantStreamState()
    private let providerCanonicalMemoryIngressLock = NSLock()
    private var providerQuestionObservedAt: Date?
    private var providerFirstTextKeys = Set<String>()
    private var providerFirstAudioKeys = Set<String>()
    private var providerCallbackOrdinal: UInt64 = 0
    private let rawCanonicalIngressRouter = DialogProviderCanonicalIngressRouter()

    /// 引擎是否就绪（已初始化完成）
    private(set) var isEngineReady = false

    /// 是否有活跃对话
    private(set) var isDialogActive = false

    /// Recorder transport may pause while the Digital Human speaks without
    /// ending the provider conversation or the product-level Live session.
    private(set) var isRecorderPaused = false
    private(set) var sessionLifetimePolicy: DialogSessionLifetimePolicy = .automatic
    private(set) var answerAuthority: DialogAnswerAuthority = .provider

    /// AI 是否正在语音播报中（用于判断是否需要打断）
    private(set) var isAISpeaking = false

    /// 是否正在结束对话中（防止关键词触发后继续处理事件）
    private(set) var isEnding = false
    /// 当前话题（由业务层设置，注入到 system_role 末尾）
    var currentTopic: String?
    private var suppressGreetingForNextStart = false
    private(set) var usesTurnScopedKnowledgeContext = false
    private(set) var lastSubmittedTurnKnowledgeContextSource: String?
    private(set) var lastSubmittedTurnKnowledgeContextLength = 0

    // MARK: - Configuration

    /// 火山引擎 Dialog 服务配置
    private struct Config {
        /// 从火山控制台获取的 AppID
        var appID: String = ""
        /// 从火山控制台获取的 AppKey
        var appKey: String = ""
        /// 从火山控制台获取的 AccessToken
        var token: String = ""
        /// 用户唯一标识（用于日志追踪）
        var uid: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        /// Backend realtime proxy address. There is deliberately no Provider
        /// default: production Live can start only from a one-time ticket.
        var address: String = ""
        /// Backend realtime proxy URI
        var uri: String = ""
        /// Backend proxy placeholder resource ID
        var resourceID: String = ""
        /// 是否启用 SDK 软件 AEC 回声消除（需要 AEC 模型文件，iOS 硬件 AEC 通过 AVAudioSession voiceChat 模式已生效）
        var enableAEC: Bool = false
        /// 是否启用内置播放器
        var enablePlayer: Bool = true
        /// Backend proxy admission header. It carries a one-time DreamJourney
        /// ticket, never a Provider credential.
        var requestHeaders: [String: String] = [:]

        // MARK: - 对话能力配置

        /// Bot 名称
        var botName: String = "寻梦环游"

        /// System Prompt - 家庆回忆录 AI 人格设定
        var systemPrompt: String = """
            你是「寻梦环游」提供的 AI 回响服务，不是真人。当前身份、称谓和事实表达严格遵循后附规则；家人数字分身可以用第一人称转述已确认记忆，但仍不得声称是真人本人。你以温暖、耐心、善于倾听的家族历史学家和传记作家方式提供帮助。\
            你的工作是通过温和的提问，引导长辈回忆人生中的重要时刻、情感体验和细节，帮他们把记忆变成可以传递给家人的故事。

            【核心原则】
            1. 多问开放式问题（“什么样的”“什么味道”“谁做的”），避免是非题。
            2. 每个话题至少追问一个感官细节（味道、声音、颜色、触感、气味）。
            3. 对长辈的每句话给予积极回应，绝不评判“记错了”或“这不重要”。
            4. 说话短、慢、亲，不用长句，不用专业术语，像跟自家奶奶聊天。
            5. 触及伤痛时不追问，先共情陪伴。原则——不追问伤痛，只陪伴伤痛。

            【语音节奏】
            - 每轮回复不超过2句话。
            - 说完一个问题后留出停顿，等长辈想，不要急着接话。
            - 长辈说话时绝不打断，哪怕重复了。
            - 重要反馈重复一遍：“您说的锅巴饭，焦黄焦黄的——是那个焦黄焦黄的锅巴饭对吧？”

            【对话节奏】
            - 每轮只追问一个点，不贪多。
            - 长辈说完后，先反馈你听到了什么，再追问。
            - 话题转换跟着食物链、味道链、人物链走，不硬跳。
            - 苦难至少给2轮空间，不急着转轻。
            - 不用“回忆”“铭记”“传承”等大词，用“记得”“说说”“讲讲”。

            【话题引导框架（5层，但不强制线性）】
            1. 根（家在哪里）：小时候住的地方、门口的树/井/河、现在变了什么样。
            2. 味（吃的故事）：过年吃什么、谁做的、小时候最馅什么。
            3. 人（最亲的人）：谁最疼您、小时候谁管您最严。追问五感：声音、手、走路、习惯动作、口头禅。
            4. 事（重要时刻）：这辈子最不容易的日子、最开心的一天。
            5. 传（想留下的）：什么手艺是从上一辈学来的、想给后辈留什么。追问传承线：谁教您→您教了谁→现在谁在做。

            【感官追问】
            - 食物：什么味道？谁做的？用什么柴？出锅第一口什么感觉？
            - 地方：什么颜色？什么气味？
            - 人物：说话什么声音？手摸起来粗糙还是软的？有什么口头禅？
            - 事件：当时穿的什么？天气怎么样？心里什么感觉？

            【情绪应对】
            - 长时间沉默：等待，不追问。
            - 哽咽/声音颤抖：停止追问，说“那段日子确实不容易……不说了吧”。
            - 笑出声：追问细节，这是金矿！
            - 语速突然变快：放慢自己语速，引导展开。
            - 叹气：共情回应“是啊……”然后给停顿。
            - 重复说同一件事：说明这件事很重要，不打断、不提醒“您说过”。

            【方言处理】
            遇到方言词/地方说法时，追问含义：“这个在您老家是什么意思？”
            """

        /// 开场白问题库（每次随机选一个播报，为空则不播报）
        var greetings: [String] = [
            "您好呀，我是寻梦环游，今天想跟您说说话不？",
            "又见面啦，今天过得怎么样？",
            "您好，最近有什么开心的事想说说吗？",
            "喔，您来啦，今天想聊点什么？",
            "您好呀，今天有什么新鲜事想跟我讲讲？",
            "您好，今天天气怎么样？跟我聊聊呗？",
            "又是新的一天，想跟您说说话，您有空不？"
        ]

        /// ASR 热词列表（提升识别准确率）
        var hotwords: [String] = [
            "寻梦环游", "家书", "回忆录", "老家",
            "锅巴饭", "大灶", "柴火", "过年",
            "奶奶", "爷爷", "外婆", "外公",
            "小时候", "老房子", "手艺", "传承"
        ]

        /// TTS 语速倍率（0.8 = 比正常慢 1.2 倍，适老）
        var speechRate: Double = 0.8

        // MARK: - 对话结束机制

        /// 触发结束对话的关键词列表（ASR 识别结果包含其中任一则结束）
        var endKeywords: [String] = [
            "生成回忆录", "生成家书", "写家书",
            "停止", "结束", "不聊了", "再见",
            "我要去忙了", "先这样吧", "下次再聊"
        ]

        /// 静音超时时长（秒），无语音输入超过此时间自动结束对话
        var silenceTimeoutSeconds: TimeInterval = 60

        var isProductionReady: Bool {
            Self.isConfiguredValue(appID) &&
                Self.isConfiguredValue(appKey) &&
                Self.isConfiguredValue(token) &&
                Self.isConfiguredValue(address) &&
                Self.isConfiguredValue(uri) &&
                Self.isConfiguredValue(resourceID) &&
                !requestHeaders.isEmpty
        }

        static func isConfiguredValue(_ value: String) -> Bool {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard !trimmed.hasPrefix("$(") else { return false }
            return !trimmed.hasPrefix("YOUR_")
        }
    }

    /// 当前配置
    private var config = Config()
    var currentConfigurationIsProductionReady: Bool { config.isProductionReady }
    var isLocalTTSPlaybackEnabled: Bool { config.enablePlayer }

    // MARK: - Private

    private static let defaultTTSSpeaker = "zh_male_yunzhou_jupiter_bigtts"

    private var engine: SpeechEngine?
    private var isSettingUp = false
    #if DEBUG && !LIVE_MANAGER_CONTROLLED_SDK
    private var t06ControlledWebSocketClient: DialogT06ControlledWebSocketClient?
    #endif

    /// 静音超时计时器
    private var silenceTimer: Timer?

    /// 当前对话结束原因（用于回调时传递）
    private var pendingEndReason: DialogEndReason = .manual

    /// AI 回复流式拼接缓冲区
    private var chatBuffer: String = ""

    private override init() {
        super.init()
    }

    @discardableResult
    func bindAccountLease(
        _ accountLease: AccountLease,
        ownerId: UUID
    ) -> DialogEngineBindingHandle? {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        if let boundBindingHandle,
           boundBindingHandle.ownerId == ownerId,
           isSameDialogAccountGeneration(boundBindingHandle.accountLease, accountLease) {
            let rotatedHandle = DialogEngineBindingHandle(
                bindingId: boundBindingHandle.bindingId,
                ownerId: ownerId,
                accountLease: accountLease
            )
            self.boundBindingHandle = rotatedHandle
            boundAccountLease = accountLease
            if engineBindingId == rotatedHandle.bindingId {
                engineAccountLease = accountLease
            }
            if activeDialogBindingHandle?.bindingId == rotatedHandle.bindingId {
                activeDialogBindingHandle = rotatedHandle
                activeDialogAccountLease = accountLease
            }
            return rotatedHandle
        }

        if boundBindingHandle != nil {
            destroyEngine()
            scopedTTSVoiceSelectionStore.clearAll()
            delegate = nil
        }
        let handle = DialogEngineBindingHandle(
            bindingId: UUID(),
            ownerId: ownerId,
            accountLease: accountLease
        )
        boundBindingHandle = handle
        boundAccountLease = accountLease
        return handle
    }

    @discardableResult
    func unbindAccountLease(_ handle: DialogEngineBindingHandle) -> Bool {
        guard boundBindingHandle == handle else { return false }
        destroyEngine()
        _ = scopedTTSVoiceSelectionStore.clear(bindingID: handle.bindingId)
        boundBindingHandle = nil
        boundAccountLease = nil
        delegate = nil
        return true
    }

    func isCurrentBinding(_ handle: DialogEngineBindingHandle?) -> Bool {
        guard let handle,
              boundBindingHandle == handle else { return false }
        return accountLeaseRuntime.validate(handle.accountLease, at: .runtime).allowed
    }

    /// Echo owns the session through AudioSessionCoordinator; the dialog engine must
    /// only reuse the exact active lease and never configure it a second time.
    @discardableResult
    func adoptExternallyManagedAudioSessionLease(_ lease: AudioOwnerLease) -> Bool {
        guard AudioSessionCoordinator.shared.isCurrentActiveLease(lease) else {
            externallyManagedAudioSessionLease = nil
            return false
        }
        externallyManagedAudioSessionLease = lease
        return true
    }

    private func isActiveAccountLeaseValid(at checkpoint: AccountLeaseCheckpoint) -> Bool {
        guard let accountLease = activeDialogAccountLease ?? engineAccountLease ?? boundAccountLease else {
            return false
        }
        return accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    // MARK: - Public API

    @discardableResult
    func setLocalTTSPlaybackEnabled(_ enabled: Bool) -> Bool {
        guard config.enablePlayer != enabled else {
            return true
        }
        guard !isDialogActive else {
            DDLogWarn("[DialogEngine] 对话进行中，跳过本地 TTS 播放开关切换")
            return false
        }

        config.enablePlayer = enabled
        print("[DialogEngine] local TTS playback \(enabled ? "enabled" : "disabled")")
        DDLogInfo("[DialogEngine] 本地 TTS 播放已\(enabled ? "开启" : "关闭")")

        if isEngineReady {
            destroyEngine()
        }
        return true
    }

    @discardableResult
    func setLocalTTSVoiceSelection(
        voiceProfileId: String?,
        contextKey: String,
        lifecycleGeneration: UInt64,
        for handle: DialogEngineBindingHandle
    ) -> Bool {
        guard isCurrentBinding(handle) else { return false }
        return scopedTTSVoiceSelectionStore.update(
            bindingID: handle.bindingId,
            accountLease: handle.accountLease,
            contextKey: contextKey,
            lifecycleGeneration: lifecycleGeneration,
            voiceProfileId: voiceProfileId
        )
    }

    /// Applies a backend-issued, one-time proxy ticket. Provider credentials
    /// and the upstream Provider address never enter the app bundle.
    @discardableResult
    func configure(runtimeConfig: RealtimeVoiceRuntimeConfig) -> Bool {
        guard !runtimeConfig.mobileDirectAllowed,
              runtimeConfig.accessPath == "backendRealtimeProxy",
              runtimeConfig.credentialMode == "oneTimeBackendProxyTicket",
              !runtimeConfig.isBlocked,
              let address = runtimeConfig.proxyAddress,
              let uri = runtimeConfig.proxyURI,
              let token = runtimeConfig.sessionToken,
              let header = runtimeConfig.sessionHeader,
              let clientID = runtimeConfig.sdkClientID,
              let clientKey = runtimeConfig.sdkClientKey,
              let resourceID = runtimeConfig.sdkResourceID else {
            DDLogWarn(
                "[DialogEngine] providerCredentialBlocked " +
                "mode=\(runtimeConfig.credentialMode) " +
                "path=\(runtimeConfig.accessPath) " +
                "reason=\(runtimeConfig.decisionReasonCode ?? "unknown") " +
                "fallback=\(runtimeConfig.fallbackMode ?? "text")"
            )
            return false
        }
        if isDialogActive {
            DDLogWarn("[DialogEngine] active Live session refuses runtime reconfiguration")
            return false
        }
        if isEngineReady {
            destroyEngine()
        }
        config.appID = clientID
        config.appKey = clientKey
        config.token = token
        config.address = address
        config.uri = uri
        config.resourceID = resourceID
        config.uid = runtimeConfig.uid ?? config.uid
        config.requestHeaders = [header: token]
        runtimeSystemRole = runtimeConfig.systemRole
        runtimeSpeakingStyle = runtimeConfig.speakingStyle
        runtimeFormalMemorySnapshot = runtimeConfig.formalMemorySnapshot
        runtimeProviderRoleText = runtimeConfig.providerRoleText
        runtimeProviderContextHash = runtimeConfig.providerContextHash
        runtimeContextUpdateTicketID = runtimeConfig.contextUpdateTicketID
        runtimeProjectionCheckpoint = runtimeConfig.projectionCheckpoint
        runtimeMemoryRevision = runtimeConfig.memoryRevision
        runtimeProductSessionID = runtimeConfig.productSessionID
        recordLiveSnapshotDecoded(runtimeConfig)
        DDLogInfo("[DialogEngine] backend realtime proxy ticket applied")
        return true
    }

    func observeLiveContextASR(_ text: String, isFinal: Bool) {
        guard isProviderOwnedLive, isDialogActive, !isEnding else { return }
        let before = liveContextUpdates.fetching?.id
        liveContextUpdates.observeASR(text, isFinal: isFinal)
        if before != liveContextUpdates.fetching?.id {
            liveContextReadControl?.cancel()
            liveContextReadControl = nil
        }
    }

    /// Called only after Echo accepted actual player completion and elected to keep listening.
    func updateLiveContextAfterPlayback() {
        guard isProviderOwnedLive, isDialogActive, !isEnding, !isAISpeaking,
              liveFarewellRequest == nil,
              let operation = activeDialogOperationId,
              let lease = activeDialogAccountLease,
              accountLeaseRuntime.validate(lease, at: .request).allowed,
              let request = liveContextUpdates.afterPlaybackDrained(now: ProcessInfo.processInfo.systemUptime),
              request.operation == operation else { return }
        recordNativeLiveDiagnostic(event: "contextUpdateRead", reason: "playbackDrained")
        liveContextReadControl = liveContextClient.fetchLiveContextUpdate(
            request: request, applicationLease: lease
        ) { [weak self] result in
            guard let self, self.activeDialogOperationId == operation,
                  self.activeDialogAccountLease == lease,
                  self.accountLeaseRuntime.validate(lease, at: .runtime).allowed,
                  self.isDialogActive, !self.isEnding, !self.isAISpeaking,
                  self.liveFarewellRequest == nil else { return }
            switch result {
            case .failure:
                self.liveContextUpdates.readFailed(request)
                self.recordNativeLiveDiagnostic(event: "contextUpdateSkipped", reason: "readUnavailable")
            case .success(let grant):
                guard grant.sequence == request.sequence, grant.previousHash == request.previousHash,
                      grant.expiresAt > Date().timeIntervalSince1970,
                      let engine = self.engine,
                      let data = try? JSONSerialization.data(withJSONObject: ["dialog": ["system_role": grant.envelope]]),
                      let json = String(data: data, encoding: .utf8),
                      self.liveContextUpdates.prepareSend(request, hash: grant.hash,
                          now: ProcessInfo.processInfo.systemUptime) else { return }
                let code = engine.send(SEDirectiveEventUpdateConfig, data: json)
                guard code == SENoError else {
                    self.liveContextUpdates.disable()
                    self.recordNativeLiveDiagnostic(event: "contextUpdateSkipped", reason: "sdkRejected")
                    return
                }
                self.recordNativeLiveDiagnostic(event: "contextUpdateSubmitted", reason: "authorizedGrant")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, self.activeDialogOperationId == operation else { return }
                    self.liveContextUpdates.expireACK(requestID: request.id, now: ProcessInfo.processInfo.systemUptime)
                    if self.liveContextUpdates.disabled {
                        self.recordNativeLiveDiagnostic(event: "contextUpdateSkipped", reason: "ackDeadline")
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.activeDialogOperationId == operation else { return }
            self.liveContextUpdates.readFailed(request)
        }
    }

    #if LIVE_MANAGER_CONTROLLED_SDK
    func setLiveContextClientForTesting(_ client: DreamJourneyBackendClient?) {
        liveContextClient = client ?? .shared
    }
    var liveContextStateForTesting: LiveContextUpdateState { liveContextUpdates }
    #endif

    private func resetLiveContextUpdates() {
        liveContextReadControl?.cancel()
        liveContextReadControl = nil
        liveContextUpdates.end()
    }

    /// 客户端主动打断 AI 回复（仅在 AI 正在播报时生效）
    @discardableResult
    func interruptAI() -> Bool {
        interruptAI(notifiesUserInterruption: false)
    }

    @discardableResult
    private func interruptAI(notifiesUserInterruption: Bool) -> Bool {
        guard isDialogActive,
              isAISpeaking || isDelegatedClientTTSSubmissionPending,
              let engine = engine else { return false }
        let callbackContext = currentProviderCallbackContext()
        let delegatedLivePlayback = sessionLifetimePolicy == .userControlledLive
            && answerAuthority == .dreamJourneyBackend
        let speakingBefore = isAISpeaking
        let result = engine.send(SEDirectiveEventClientInterrupt, data: "{}")
        recordNativeLiveDiagnostic(
            event: "clientInterrupt",
            reason: notifiesUserInterruption ? "newBoundQuestion" : "explicitRequest",
            speakingBefore: speakingBefore,
            speakingAfter: result == SENoError ? false : speakingBefore,
            resultCode: Int(result.rawValue)
        )
        if result == SENoError {
            if delegatedLivePlayback, let callbackContext {
                _ = emitDelegatedPlaybackProgress(
                    .interrupted(replyID: delegatedClientPlaybackReplyID),
                    callbackContext: callbackContext
                )
            }
            isAISpeaking = false
            providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
            providerInterruptionState.clearAudibleReply()
            resetDelegatedClientPlaybackState()
            print("[DialogEngine] ✅ 已打断 AI 播报")
            DDLogInfo("[DialogEngine] 客户端打断 AI")
            if notifiesUserInterruption,
               !delegatedLivePlayback,
               let callbackContext = currentProviderCallbackContext() {
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onTTSPlaybackInterruptedByUser()
                }
            }
            return true
        } else {
            print("[DialogEngine] ⚠️ 打断指令发送失败: \(result.rawValue)")
            return false
        }
    }

    /// 初始化引擎（预加载）
    func setup() {
        guard let setupAccountLease = boundAccountLease,
              let setupBindingHandle = boundBindingHandle,
              accountLeaseRuntime.validate(setupAccountLease, at: .request).allowed else {
            return
        }
        guard !isEngineReady else {
            DDLogInfo("[DialogEngine] 引擎已就绪，跳过重复初始化")
            return
        }

        guard !isSettingUp else {
            DDLogInfo("[DialogEngine] 正在初始化中，跳过")
            return
        }

        isSettingUp = true

        guard config.isProductionReady else {
            print("[DialogEngine] ❌ 生产语音 SDK 配置缺失或仍为占位值")
            DDLogError("[DialogEngine] 生产语音 SDK 配置缺失或仍为占位值")
            isSettingUp = false
            delegate?.onError(error: DialogEngineError.productionConfigurationMissing)
            return
        }

        // 准备环境（首次调用）
        SpeechEngine.prepareEnvironment()

        // 创建引擎实例
        let speechEngine = SpeechEngine()
        let callbackGeneration = UUID()
        let delegateProxy = DialogEngineProviderDelegateProxy(
            owner: self,
            engineGeneration: callbackGeneration
        )
        let created = speechEngine.createEngine(with: delegateProxy)
        guard created else {
            DDLogError("[DialogEngine] createEngine 失败")
            isSettingUp = false
            delegate?.onError(error: DialogEngineError.initFailed(code: -1))
            return
        }

        #if DEBUG && !LIVE_MANAGER_CONTROLLED_SDK
        if DialogT06DiagnosticMode.isEnabled {
            let controlledClient = DialogT06ControlledWebSocketClient()
            t06ControlledWebSocketClient = controlledClient
            speechEngine.setWsClient(controlledClient)
        } else {
            t06ControlledWebSocketClient = nil
        }
        #endif

        // 配置引擎参数
        configureEngine(speechEngine)

        // 初始化引擎
        let result = speechEngine.initEngine()
        isSettingUp = false

        print("[DialogEngine] initEngine 返回: \(result.rawValue)")
        if result == SENoError {
            guard let currentBindingHandle = boundBindingHandle,
                  currentBindingHandle.bindingId == setupBindingHandle.bindingId,
                  isSameDialogAccountGeneration(currentBindingHandle.accountLease, setupAccountLease),
                  accountLeaseRuntime.validate(currentBindingHandle.accountLease, at: .runtime).allowed else {
                speechEngine.destroy()
                return
            }
            self.engine = speechEngine
            self.engineAccountLease = currentBindingHandle.accountLease
            self.engineBindingId = currentBindingHandle.bindingId
            self.engineCallbackGeneration = callbackGeneration
            self.engineDelegateProxy = delegateProxy
            self.engineAnswerAuthority = answerAuthority
            self.engineUsesDelegatedLivePlayback = sessionLifetimePolicy == .userControlledLive
                && answerAuthority == .dreamJourneyBackend
            self.isEngineReady = true
            print("[DialogEngine] ✅ 引擎初始化成功")
            DDLogInfo("[DialogEngine] 引擎初始化成功")
        } else {
            print("[DialogEngine] ❌ 引擎初始化失败: \(result.rawValue)")
            DDLogError("[DialogEngine] 引擎初始化失败: \(result.rawValue)")
            speechEngine.destroy()
            delegate?.onError(error: DialogEngineError.initFailed(code: Int(result.rawValue)))
        }
    }

    /// 开始语音对话
    func startDialog(
        sendsGreeting: Bool = true,
        usesTurnScopedKnowledgeContext: Bool = false,
        lifetimePolicy: DialogSessionLifetimePolicy = .automatic,
        answerAuthority: DialogAnswerAuthority = .provider,
        voiceLaunchID: String? = nil,
        voiceLaunchIsValid: (() -> Bool)? = nil
    ) {
        guard let accountLease = boundAccountLease,
              let bindingHandle = boundBindingHandle,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              voiceLaunchIsValid?() ?? true else {
            return
        }
        if isDialogActive, let engine {
            _ = engine.send(SEDirectiveSyncStopEngine)
            isDialogActive = false
            activeDialogAccountLease = nil
            activeDialogBindingHandle = nil
            resetLiveContextUpdates()
            activeDialogOperationId = nil
            voiceLaunchControl.invalidate()
            providerSessionOperationId = nil
            requiresEngineRecreationBeforeNextDialog = true
        }
        rotateProviderEngineBeforeNextDialogIfNeeded()
        let usesDelegatedLivePlayback = lifetimePolicy == .userControlledLive
            && answerAuthority == .dreamJourneyBackend
        if isEngineReady,
           (engineAnswerAuthority != answerAuthority
            || engineUsesDelegatedLivePlayback != usesDelegatedLivePlayback) {
            destroyEngine()
        }
        let dialogOperationId = UUID()
        activeDialogAccountLease = accountLease
        activeDialogBindingHandle = bindingHandle
        activeDialogOperationId = dialogOperationId
        resetLiveContextUpdates()
        liveContextUpdates.begin(operation: dialogOperationId, ticketID: runtimeContextUpdateTicketID, hash: runtimeProviderContextHash)
        pendingVoiceLaunchID = voiceLaunchID
        voiceLaunchControl.begin(
            operationID: dialogOperationId,
            pendingID: voiceLaunchID,
            isValid: voiceLaunchIsValid
        )
        pendingVoiceStartSubmitted = false
        if let engineCallbackGeneration {
            providerTurnCorrelation.beginSession(generation: engineCallbackGeneration)
            providerInterruptionState.beginSession(generation: engineCallbackGeneration)
        }
        self.usesTurnScopedKnowledgeContext = usesTurnScopedKnowledgeContext
        sessionLifetimePolicy = lifetimePolicy
        self.answerAuthority = answerAuthority
        liveStartSubmittedAt = nil
        liveStartDirectiveReturnCode = nil
        liveFirstResponseObserved = false
        providerActiveChatReplyID = nil
        providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
        providerCanonicalAssistantTextState.reset()
        providerCanonicalAssistantStreamState.reset()
        providerQuestionObservedAt = nil
        providerFirstTextKeys.removeAll()
        providerFirstAudioKeys.removeAll()
        chatBuffer = ""
        resetDelegatedTTSRoutingState()
        isRecorderPaused = false
        suppressGreetingForNextStart = !sendsGreeting
        // 引擎未就绪时先初始化
        guard isEngineReady, engine != nil else {
            DDLogInfo("[DialogEngine] 引擎未就绪，先初始化")
            setup()
            guard voiceLaunchStillValid(dialogOperationId) else {
                cancelPendingVoiceLaunch(id: voiceLaunchID)
                return
            }
            if isEngineReady {
                performStartDialog(
                    accountLease: accountLease,
                    bindingHandle: bindingHandle,
                    dialogOperationId: dialogOperationId
                )
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self,
                      self.boundBindingHandle == bindingHandle,
                      self.activeDialogBindingHandle == bindingHandle,
                      self.activeDialogOperationId == dialogOperationId,
                      self.activeDialogAccountLease == accountLease,
                      self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                      self.isEngineReady else { return }
                guard self.voiceLaunchStillValid(dialogOperationId) else {
                    self.cancelPendingVoiceLaunch(id: voiceLaunchID)
                    return
                }
                self.performStartDialog(
                    accountLease: accountLease,
                    bindingHandle: bindingHandle,
                    dialogOperationId: dialogOperationId
                )
            }
            return
        }

        performStartDialog(
            accountLease: accountLease,
            bindingHandle: bindingHandle,
            dialogOperationId: dialogOperationId
        )
    }

    private func voiceLaunchStillValid(_ operationID: UUID) -> Bool {
        activeDialogOperationId == operationID && voiceLaunchControl.permits(operationID)
    }

    func cancelPendingVoiceLaunch(id: String?) {
        guard voiceLaunchControl.cancel(pendingID: id) else { return }
        finishCancelledVoiceLaunch()
    }

    private func cancelPendingVoiceLaunch(operationID: UUID) {
        guard activeDialogOperationId == operationID,
              voiceLaunchControl.cancel(operationID: operationID) else { return }
        finishCancelledVoiceLaunch()
    }

    private func finishCancelledVoiceLaunch() {
        pendingVoiceLaunchID = nil
        if isDialogActive {
            stopDialog()
            return
        }
        // A launch can own ingress before SessionStarted. Pending cancellation
        // must close that exact operation too; clearing IDs alone leaves the
        // synchronous transcript ingress bound to a cancelled capture.
        if let operationID = activeDialogOperationId {
            closeRawCanonicalIngressBinding(expectedDialogOperationID: operationID)
        }
        if pendingVoiceStartSubmitted, let engine {
            _ = engine.send(SEDirectiveSyncStopEngine)
        }
        pendingVoiceStartSubmitted = false
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        resetLiveContextUpdates()
        activeDialogOperationId = nil
        voiceLaunchControl.invalidate()
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        restoreAudioSessionIfNeeded()
    }

    func completeVoiceLaunch(id: String) {
        guard isDialogActive, voiceLaunchControl.complete(pendingID: id) else { return }
        pendingVoiceLaunchID = nil
        pendingVoiceStartSubmitted = false
    }

    /// Speaks a backend-generated text reply through the same Fire realtime
    /// dialog transport and role-bound speaker used by Live. The recorder is
    /// paused before text is injected, so this one-shot route cannot create a
    /// second user turn or mutate the Live conversation.
    @discardableResult
    func startTextReplyPlayback(
        text: String,
        onStarted: @escaping () -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            completion(.failure(DialogTextReplyPlaybackError.invalidText))
            return false
        }
        guard pendingTextReplyPlayback == nil,
              !isDialogActive,
              config.enablePlayer,
              currentConfigurationIsProductionReady,
              boundBindingHandle != nil else {
            completion(.failure(DialogTextReplyPlaybackError.sessionBusy))
            return false
        }

        pendingTextReplyPlayback = DialogEngineTextReplyPlayback(
            id: UUID(),
            text: normalized,
            onStarted: onStarted,
            completion: completion
        )
        startDialog(
            sendsGreeting: false,
            usesTurnScopedKnowledgeContext: true,
            lifetimePolicy: .automatic
        )
        guard isEngineReady, activeDialogOperationId != nil else {
            completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: true
            )
            return false
        }
        return true
    }

    func cancelTextReplyPlayback() {
        guard pendingTextReplyPlayback != nil else { return }
        textReplyPlaybackFallbackWorkItem?.cancel()
        textReplyPlaybackFallbackWorkItem = nil
        pendingTextReplyPlayback = nil
        closeTextReplyProviderSession()
    }

    /// 结束语音对话
    func stopDialog(onInputSealed: (() -> Void)? = nil) {
        stopDialog(reason: .manual, onInputSealed: onInputSealed)
    }

    /// Seal business input before entering the external synchronous stop. The
    /// durable close must not depend on SDK completion or delegate delivery.
    func stopDialog(reason: DialogEndReason, onInputSealed: (() -> Void)? = nil) {
        if pendingTextReplyPlayback != nil {
            onInputSealed?()
            cancelTextReplyPlayback()
            return
        }
        guard isDialogActive,
              let engine,
              let callbackContext = currentProviderCallbackContext() else {
            if let onInputSealed {
                if let generation = engineCallbackGeneration {
                    _ = rawCanonicalIngressRouter.sealActiveOwnerForStop(engineGeneration: generation)
                }
                closeRawCanonicalIngressBinding(expectedDialogOperationID: activeDialogOperationId)
                onInputSealed()
            }
            return
        }

        _ = rawCanonicalIngressRouter.sealActiveOwnerForStop(
            engineGeneration: callbackContext.engineGeneration
        )
        closeRawCanonicalIngressBinding(
            expectedDialogOperationID: callbackContext.dialogOperationId
        )
        onInputSealed?()
        isEnding = true
        invalidateSilenceTimer()
        resetDelegatedClientPlaybackState()
        providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
        providerInterruptionState.clearAudibleReply()
        pendingEndReason = reason

        // 同步停止引擎（官方推荐）
        let result = engine.send(SEDirectiveSyncStopEngine)
        if result != SENoError {
            DDLogError("[DialogEngine] SyncStopEngine 失败: \(result.rawValue)")
        }

        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        isEnding = false
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        resetLiveContextUpdates()
        activeDialogOperationId = nil
        voiceLaunchControl.invalidate()
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        restoreAudioSessionIfNeeded()

        switch reason {
        case .keyword(let kw):
            print("[DialogEngine] 🛑 关键词触发结束: \(kw)")
            DDLogInfo("[DialogEngine] 关键词触发结束: \(kw)")
        case .silenceTimeout:
            print("[DialogEngine] ⏰ 静音超时触发结束")
            DDLogInfo("[DialogEngine] 静音超时触发结束")
        default:
            DDLogInfo("[DialogEngine] 对话已停止")
        }

        deliverProviderCallback(
            callbackContext,
            requiresActiveOperation: false
        ) { _, delegate in
            delegate.onDialogEnded(reason: reason)
        }
    }

    /// Temporarily releases microphone capture while preserving the same
    /// realtime provider session and its accumulated conversation context.
    @discardableResult
    func pauseRecorder() -> Bool {
        guard isDialogActive, !isRecorderPaused, let engine else {
            return isDialogActive && isRecorderPaused
        }
        let result = engine.send(SEDirectivePauseRecorder)
        guard result == SENoError else {
            DDLogError("[DialogEngine] PauseRecorder failed: \(result.rawValue)")
            return false
        }
        isRecorderPaused = true
        invalidateSilenceTimer()
        DDLogInfo("[DialogEngine] recorder paused; provider Live session preserved")
        return true
    }

    @discardableResult
    func resumeRecorder() -> Bool {
        resumeRecorderOutcome().isSuccess
    }

    @discardableResult
    func resumeRecorderOutcome() -> DialogRecorderResumeOutcome {
        guard isDialogActive else { return .sessionInactive }
        guard isRecorderPaused else {
            resetSilenceTimer()
            return .alreadyRunning
        }
        guard let engine else { return .sessionInactive }
        let result = engine.send(SEDirectiveResumeRecorder)
        guard result == SENoError else {
            DDLogError("[DialogEngine] ResumeRecorder failed: \(result.rawValue)")
            return .directiveRejected(code: Int(result.rawValue))
        }
        isRecorderPaused = false
        resetSilenceTimer()
        DDLogInfo("[DialogEngine] recorder resumed in existing provider Live session")
        return .directiveSent
    }

    /// Product farewell uses the current provider connection, speaker and native
    /// player. It is not a user query, a normal answer, or a second TTS session.
    @discardableResult
    func submitLiveFarewell(_ content: String, bindingHandle: DialogEngineBindingHandle?,
        completion: @escaping () -> Void) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, isCurrentBinding(bindingHandle),
              isDialogActive, !isEnding, !isAISpeaking, isRecorderPaused,
              sessionLifetimePolicy == .userControlledLive, config.enablePlayer,
              pendingTextReplyPlayback == nil, liveFarewellRequest == nil,
              let context = currentProviderCallbackContext(),
              isCurrentProviderCallbackContext(context, checkpoint: .request, requiresActiveOperation: true),
              let engine,
              let bytes = try? JSONSerialization.data(withJSONObject: ["content": text]),
              let payload = String(data: bytes, encoding: .utf8),
              selectDelegatedClientTTSRouteIfNeeded() else { return false }
        invalidateSilenceTimer()
        liveFarewellRequest = DialogLiveFarewellRequest(context: context,
            excludedReplyIDs: observedLiveReplyIDs, completion: completion)
        providerCanonicalMemoryIngressLock.lock()
        farewellIngressScope = (context.engineGeneration, observedLiveReplyIDs)
        providerCanonicalMemoryIngressLock.unlock()
        let result = engine.send(SEDirectiveEventSayHello, data: payload)
        guard result == SENoError else {
            liveFarewellRequest = nil
            recordNativeLiveDiagnostic(event: "liveFarewellRejected", resultCode: Int(result.rawValue))
            return false
        }
        recordNativeLiveDiagnostic(event: "liveFarewellSubmitted", reason: "currentSessionVoice")
        return true
    }

    private func completeLiveFarewell(reason: String) {
        guard let request = liveFarewellRequest else { return }
        liveFarewellRequest = nil
        isAISpeaking = false
        recordNativeLiveDiagnostic(event: "liveFarewellTerminal", replyID: request.replyID, reason: reason)
        // Keep the ingress exclusion until stop closes the binding. The caller
        // owns its existing 20-second budget and the durable close operation.
        guard isCurrentProviderCallbackContext(request.context,
            checkpoint: .runtime, requiresActiveOperation: true) else { return }
        request.completion()
    }

    private func consumeLiveFarewell(_ frozen: DialogEngineFrozenProviderMessage) -> Bool {
        guard var request = liveFarewellRequest else { return false }
        let type = frozen.type
        let data = frozen.data
        let metadata = frozen.metadata
        let generation = request.context.engineGeneration
        guard generation == frozen.engineGeneration else { return true }
        var drained = false
        switch type {
        case SEEventTTSSentenceStart:
            guard metadata.ttsType == "chat_tts_text", let id = metadata.replyID,
                  !request.excludedReplyIDs.contains(id),
                  request.replyID == nil || request.replyID == id else { return true }
            request.replyID = id
            isAISpeaking = true
        case SEEventTTSEnded:
            guard let id = request.replyID, metadata.replyID == id else { return true }
            request.pcm.synthesized(replyID: id, generation: generation)
            drained = request.player.receive(.synthesisEnded, replyID: id,
                generation: generation) == .drained && request.observedAudio
        case SEDecoderAudioData:
            if request.replyID != nil, DialogPCM16WaveEncoder.containsAudibleSamples(data) {
                request.observedAudio = true
            }
            request.pcm.decoded(data, replyID: request.replyID, generation: generation)
        case SEPlayerAudioData:
            if request.replyID != nil, DialogPCM16WaveEncoder.containsAudibleSamples(data) {
                request.observedAudio = true
            }
            drained = request.pcm.played(data, replyID: request.replyID, generation: generation)
        case SEPlayerStartPlayAudio:
            _ = request.player.receive(.playerStarted, replyID: request.replyID, generation: generation)
        case SEPlayerFinishPlayAudio:
            drained = request.player.receive(.playerFinished, replyID: request.replyID,
                generation: generation) == .drained && request.observedAudio
        case SEEventTTSSentenceEnd, SEEventTTSResponse, SEEventChatResponse, SEEventChatEnded,
             SEEventASRInfo, SEEventASRResponse, SEEventASREnded, SEEventChatTextQueryConfirmed:
            // Owner ingress was already durably observed before this UI queue;
            // never turn the product farewell into an ordinary answer/turn.
            break
        case SEEngineError, SEEngineStop, SEEventConnectionFailed, SEEventConnectionFinished,
             SEEventSessionFailed, SEEventSessionFinished, SEEventSessionCanceled:
            completeLiveFarewell(reason: "providerUnavailable")
            return true
        default:
            return false
        }
        liveFarewellRequest = request
        if drained && !request.pcm.invalid { completeLiveFarewell(reason: "playbackDrained") }
        return true
    }

    /// 播报开场白（对应豆包SDK的 SayHello 事件 3006）
    /// 应在引擎启动成功（SEEngineStart 回调）后调用
    func sayHello(_ content: String? = nil) {
        guard let engine = engine else { return }
        let greeting = content ?? "您好呀，我是寻梦环游，今天想跟您聊聊天，听听您的故事。"
        let json = "{\"content\": \"\(greeting)\"}"
        engine.send(SEDirectiveEventSayHello, data: json)
        DDLogInfo("[DialogEngine] greeting submitted characters=\(greeting.count)")
    }

    /// 客户端打断AI（对应豆包SDK的 ClientInterrupt 事件 3010）
    /// 当AI正在说话时用户开口说话，可调用此方法打断
    func clientInterrupt() {
        guard let engine = engine else { return }
        engine.send(SEDirectiveEventClientInterrupt, data: "{}")
        DDLogInfo("[DialogEngine] 发送打断指令")
    }

    /// Sends a contract-valid external RAG payload for isolated capability
    /// probes. The provider does not document a same-turn generation barrier,
    /// so a successful SDK return must not be treated as same-turn adoption.
    @discardableResult
    func submitTurnKnowledgeContext(
        _ content: String,
        traceID: String?,
        source: String
    ) -> Bool {
        guard isDialogActive, usesTurnScopedKnowledgeContext, let engine else {
            DDLogWarn("[DialogEngine] 忽略 turn RAG：对话未激活")
            return false
        }
        guard let payload = try? DialogChatRAGTextPayloadEncoder.encode(content: content) else {
            DDLogError("[DialogEngine] turn RAG JSON 编码失败")
            return false
        }

        let result = engine.send(SEDirectiveEventChatRagText, data: payload)
        guard result == SENoError else {
            DDLogError("[DialogEngine] turn RAG 提交失败: \(result.rawValue)")
            return false
        }
        lastSubmittedTurnKnowledgeContextSource = source
        lastSubmittedTurnKnowledgeContextLength = content.utf8.count
        DDLogInfo(
            "[DialogEngine] turn RAG 已提交 source=\(source) " +
            "traceID=\(traceID ?? "none") bytes=\(content.utf8.count)"
        )
        return true
    }

    /// Sends the answer generated by DreamJourney `/echo/answers` back into the
    /// current provider session for TTS. The Dialog engine runs in delegated-chat
    /// mode, so Fire keeps ASR/TTS while DreamJourney remains the only answer
    /// authority for Live and typed Echo.
    @discardableResult
    func submitLiveAnswerText(
        _ content: String,
        traceID: String?,
        source: String
    ) -> Bool {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDialogActive,
              sessionLifetimePolicy == .userControlledLive,
              answerAuthority == .dreamJourneyBackend,
              isDelegatedClientTTSRouteSelected,
              config.enablePlayer,
              let engine,
              !normalized.isEmpty else {
            DDLogWarn("[DialogEngine] ignored delegated Live answer: session unavailable")
            return false
        }
        guard let payloadData = try? JSONSerialization.data(
            withJSONObject: ["content": normalized],
            options: []
        ), let payload = String(data: payloadData, encoding: .utf8) else {
            DDLogError("[DialogEngine] delegated Live answer JSON encoding failed")
            return false
        }

        resetDelegatedClientPlaybackState()
        delegatedClientPlaybackState.submit()
        isDelegatedClientTTSSubmissionPending = true

        // This SDK build reliably routes SayHello through the same
        // chat_tts_text stream as the audible Live greeting. ChatTtsText can
        // be swallowed while the provider-owned answer stream is finishing.
        let result = engine.send(SEDirectiveEventSayHello, data: payload)
        guard result == SENoError else {
            isDelegatedClientTTSSubmissionPending = false
            delegatedClientPlaybackState.reset()
            DDLogError("[DialogEngine] delegated Live answer rejected: \(result.rawValue)")
            return false
        }
        DDLogInfo(
            "[DialogEngine] delegated Live answer submitted directive=sayHello " +
            "source=\(source) traceID=\(traceID ?? "none") bytes=\(normalized.utf8.count)"
        )
        return true
    }

    private func selectDelegatedClientTTSRouteIfNeeded(force: Bool = false) -> Bool {
        guard answerAuthority == .dreamJourneyBackend else { return true }
        guard force || !isDelegatedClientTTSRouteSelected else { return true }
        guard let engine else { return false }

        let result = engine.send(SEDirectiveDialogUseClientTriggerTts)
        guard result == SENoError else {
            DDLogError(
                "[DialogEngine] delegated Live TTS route selection failed code=\(result.rawValue)"
            )
            return false
        }
        isDelegatedClientTTSRouteSelected = true
        DDLogInfo(
            "[DialogEngine] delegated Live TTS route selected trigger=client force=\(force)"
        )
        return true
    }

    private func resetDelegatedTTSRoutingState() {
        isDelegatedClientTTSRouteSelected = false
        delegatedClientTTSReplyIDs.removeAll()
        delegatedServerTTSReplyIDs.removeAll()
        resetDelegatedClientPlaybackState()
    }

    private func resetDelegatedClientPlaybackState() {
        delegatedClientPCMPlayer.stop()
        delegatedClientPlaybackReplyID = nil
        isDelegatedClientTTSSubmissionPending = false
        delegatedClientPlaybackState.reset()
        delegatedClientPlaybackAudioActivityObserved = false
        delegatedClientDecodedPCM.removeAll(keepingCapacity: false)
    }

    private func acceptsDelegatedTTSEvent(
        _ data: Data,
        phase: DelegatedTTSEventPhase
    ) -> Bool {
        guard answerAuthority == .dreamJourneyBackend else { return true }
        guard let metadata = delegatedTTSMetadata(from: data) else {
            DDLogWarn("[DialogEngine] dropped delegated TTS event without metadata phase=\(phase)")
            return false
        }

        switch phase {
        case .started:
            let isClientTriggered = metadata.ttsType == "chat_tts_text"
            guard let replyID = metadata.replyID else {
                DDLogWarn("[DialogEngine] dropped delegated TTS start without reply ID")
                return false
            }
            if isClientTriggered {
                guard delegatedClientPlaybackState.phase == .submitted
                    || delegatedClientPlaybackState.phase == .providerAccepted else {
                    DDLogWarn(
                        "[DialogEngine] dropped delegated TTS start without matching submission " +
                        "replyID=\(replyID) phase=\(delegatedClientPlaybackState.phase)"
                    )
                    return false
                }
                delegatedClientTTSReplyIDs.insert(replyID)
                delegatedServerTTSReplyIDs.remove(replyID)
                delegatedClientPlaybackReplyID = replyID
            } else {
                delegatedServerTTSReplyIDs.insert(replyID)
                delegatedClientTTSReplyIDs.remove(replyID)
            }
            if !isClientTriggered {
                DDLogInfo(
                    "[DialogEngine] ignored provider-owned TTS while backend owns answers " +
                    "ttsType=\(metadata.ttsType ?? "unknown")"
                )
                // The session is already pinned to client-triggered TTS. Sending
                // ClientInterrupt here also mutes the player for the following
                // SayHello response, so the ignored server stream must be left
                // to finish without taking playback ownership.
            }
            return isClientTriggered

        case .sentenceEnded:
            guard let replyID = metadata.replyID else { return false }
            return delegatedClientTTSReplyIDs.contains(replyID)

        case .streamEnded:
            guard let replyID = metadata.replyID else { return false }
            // Keep the client reply bound until the provider player reports
            // its terminal callback. Synthesis completion is not playback
            // completion.
            return delegatedClientTTSReplyIDs.contains(replyID)
        }
    }

    @discardableResult
    private func emitDelegatedPlaybackProgress(
        _ progress: DialogEngineDelegatedPlaybackProgress,
        callbackContext: DialogEngineProviderCallbackContext
    ) -> Bool {
        guard delegatedClientPlaybackState.apply(progress) else {
            DDLogWarn(
                "[DialogEngine] ignored delegated playback progress " +
                "phase=\(delegatedClientPlaybackState.phase) replyID=\(progress.replyID ?? "none")"
            )
            return false
        }
        deliverProviderCallback(callbackContext) { _, delegate in
            delegate.onDelegatedPlaybackProgress(progress)
        }
        return true
    }

    private func delegatedTTSMetadata(
        from data: Data
    ) -> (replyID: String?, ttsType: String?)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return (
            replyID: json["reply_id"] as? String,
            ttsType: json["tts_type"] as? String
        )
    }

    private func appendDelegatedClientDecodedPCM(_ data: Data) {
        guard answerAuthority == .dreamJourneyBackend else {
            print("[DialogEngine] dropped decoder PCM reason=answerAuthority")
            return
        }
        guard delegatedClientPlaybackReplyID != nil else {
            print("[DialogEngine] dropped decoder PCM reason=missingReplyID bytes=\(data.count)")
            return
        }
        guard !data.isEmpty else {
            print("[DialogEngine] dropped decoder PCM reason=empty")
            return
        }
        let hadData = !delegatedClientDecodedPCM.isEmpty
        delegatedClientDecodedPCM.append(data)
        if !hadData {
            print(
                "[DialogEngine] decoder PCM first packet bytes=\(data.count) " +
                "audible=\(DialogPCM16WaveEncoder.containsAudibleSamples(data))"
            )
            DDLogInfo(
                "[DialogEngine] delegated Live decoder received first PCM packet " +
                "bytes=\(data.count) audible=\(DialogPCM16WaveEncoder.containsAudibleSamples(data))"
            )
        }
    }

    private func playDelegatedClientDecodedPCM(
        callbackContext: DialogEngineProviderCallbackContext
    ) {
        guard let replyID = delegatedClientPlaybackReplyID else {
            return
        }
        let pcmData = delegatedClientDecodedPCM
        print(
            "[DialogEngine] decoder PCM synthesis complete bytes=\(pcmData.count) " +
            "audible=\(DialogPCM16WaveEncoder.containsAudibleSamples(pcmData))"
        )
        guard DialogPCM16WaveEncoder.containsAudibleSamples(pcmData) else {
            resetDelegatedClientPlaybackState()
            DDLogError("[DialogEngine] delegated Live decoder returned empty or silent PCM")
            deliverProviderCallback(callbackContext) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: -1,
                        message: "回响音频数据为空"
                    )
                )
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.delegatedClientPlaybackReplyID == replyID else {
                return
            }
            let started = self.delegatedClientPCMPlayer.play(
                pcmData: pcmData,
                onStarted: { [weak self] in
                    guard let self,
                          self.delegatedClientPlaybackReplyID == replyID else {
                        return
                    }
                    _ = self.delegatedClientPlaybackState.apply(
                        .audioStarted(replyID: replyID)
                    )
                    self.isAISpeaking = true
                    DDLogInfo(
                        "[DialogEngine] delegated Live PCM player started bytes=\(pcmData.count)"
                    )
                    self.deliverProviderCallback(callbackContext) { _, delegate in
                        delegate.onTTSPlaybackStarted()
                    }
                },
                completion: { [weak self] succeeded in
                    guard let self,
                          self.delegatedClientPlaybackReplyID == replyID else {
                        return
                    }
                    self.resetDelegatedClientPlaybackState()
                    self.isAISpeaking = false
                    if succeeded {
                        DDLogInfo("[DialogEngine] delegated Live PCM player finished")
                        self.deliverProviderCallback(callbackContext) { _, delegate in
                            delegate.onTTSFinished()
                        }
                    } else {
                        DDLogError("[DialogEngine] delegated Live PCM player failed")
                        self.deliverProviderCallback(callbackContext) { _, delegate in
                            delegate.onError(
                                error: DialogEngineError.sdkError(
                                    code: -2,
                                    message: "回响音频播放失败"
                                )
                            )
                        }
                    }
                }
            )
            guard started else {
                self.resetDelegatedClientPlaybackState()
                self.isAISpeaking = false
                DDLogError("[DialogEngine] delegated Live PCM player could not start")
                self.deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onError(
                        error: DialogEngineError.sdkError(
                            code: -3,
                            message: "回响音频未能开始播放"
                        )
                    )
                }
                return
            }
        }
    }

    /// 销毁引擎（登出/退出时调用）
    func destroyEngine() {
        closeRawCanonicalIngressBinding()
        let coordinatorOwnedAudioSession = DialogAudioSessionOwnershipPolicy.requiresCoordinator(
            lifetimePolicy: sessionLifetimePolicy,
            hasExternalLease: externallyManagedAudioSessionLease != nil
        )
        invalidateSilenceTimer()
        textReplyPlaybackFallbackWorkItem?.cancel()
        textReplyPlaybackFallbackWorkItem = nil
        pendingTextReplyPlayback = nil
        resetDelegatedTTSRoutingState()
        if isDialogActive {
            _ = engine?.send(SEDirectiveSyncStopEngine)
        }
        engine?.destroy()
        engine = nil
        engineAccountLease = nil
        engineBindingId = nil
        engineCallbackGeneration = nil
        engineDelegateProxy = nil
        engineAnswerAuthority = nil
        engineUsesDelegatedLivePlayback = false
        liveStartSubmittedAt = nil
        liveStartDirectiveReturnCode = nil
        liveFirstResponseObserved = false
        activeDialogBindingHandle = nil
        resetLiveContextUpdates()
        activeDialogOperationId = nil
        voiceLaunchControl.invalidate()
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = false
        activeDialogAccountLease = nil
        isEngineReady = false
        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        isEnding = false
        sessionLifetimePolicy = .automatic
        answerAuthority = .provider
        usesTurnScopedKnowledgeContext = false
        providerTurnCorrelation = DialogProviderTurnCorrelationState()
        providerReplyPlaybackState = DialogProviderReplyPlaybackState()
        providerPCMDrain.reset()
        providerInterruptionState = DialogProviderInterruptionState()
        providerActiveChatReplyID = nil
        providerQuestionObservedAt = nil
        providerFirstTextKeys.removeAll()
        providerFirstAudioKeys.removeAll()
        chatBuffer = ""
        restoreAudioSessionIfNeeded(forceCoordinatorOwnership: coordinatorOwnedAudioSession)
        externallyManagedAudioSessionLease = nil
        DDLogInfo("[DialogEngine] 引擎已销毁")
    }

    private func rotateProviderEngineBeforeNextDialogIfNeeded() {
        guard requiresEngineRecreationBeforeNextDialog else { return }
        let retiredGeneration = engineCallbackGeneration?.uuidString ?? "none"
        destroyEngine()
        DDLogInfo("[DialogEngine] 已轮换 provider callback generation，隔离上一会话晚到事件 retiredGeneration=\(retiredGeneration)")
    }

    // MARK: - Audio Session 管理

    private var shouldLetExternalTTSOwnAudioSession: Bool {
        !config.enablePlayer
    }

    /// Configures the legacy session only when a non-Echo caller owns this engine.
    /// Echo passes an exact coordinator lease and must never race this direct path.
    private func configureAudioSession() -> Bool {
        if let externallyManagedAudioSessionLease {
            guard AudioSessionCoordinator.shared.isCurrentActiveLease(externallyManagedAudioSessionLease) else {
                DDLogError("[DialogEngine] 外部 AudioSession lease 已失效，拒绝启动对话")
                delegate?.onError(error: DialogEngineError.audioSessionFailed)
                return false
            }
            DDLogInfo("[DialogEngine] 复用 Echo AudioSessionCoordinator lease")
            return true
        }

        guard DialogAudioSessionOwnershipPolicy.allowsDirectConfiguration(
            lifetimePolicy: sessionLifetimePolicy,
            hasExternalLease: false
        ) else {
            DDLogError("[DialogEngine] Echo Live 缺少 AudioSessionCoordinator lease，拒绝直接配置 AVAudioSession")
            delegate?.onError(error: DialogEngineError.audioSessionFailed)
            return false
        }

        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playAndRecord || session.mode != .voiceChat {
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            }
            try session.setActive(true)
            if shouldLetExternalTTSOwnAudioSession {
                DDLogInfo("[DialogEngine] AudioSession 配置为 playAndRecord + voiceChat，腾讯数字人远端音频接管播放")
                print("[DialogEngine] AudioSession active for external digital-human TTS playback")
            } else {
                DDLogInfo("[DialogEngine] AudioSession 配置为 playAndRecord + voiceChat")
            }
            return true
        } catch {
            DDLogError("[DialogEngine] AudioSession 配置失败: \(error.localizedDescription)")
            delegate?.onError(error: DialogEngineError.audioSessionFailed)
            return false
        }
    }

    private func restoreAudioSessionIfNeeded(forceCoordinatorOwnership: Bool = false) {
        if forceCoordinatorOwnership || DialogAudioSessionOwnershipPolicy.requiresCoordinator(
            lifetimePolicy: sessionLifetimePolicy,
            hasExternalLease: externallyManagedAudioSessionLease != nil
        ) {
            DDLogInfo("[DialogEngine] 跳过 AudioSession 恢复：AudioSessionCoordinator 持有会话")
            return
        }
        guard !shouldLetExternalTTSOwnAudioSession else {
            DDLogInfo("[DialogEngine] 跳过 AudioSession 恢复：外部数字人 TTS 仍可能在播放")
            print("[DialogEngine] skip AudioSession restore; external digital-human TTS owns playback")
            return
        }
        restoreAudioSession()
    }

    /// 恢复音频会话为默认播放模式
    private func restoreAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            DDLogInfo("[DialogEngine] AudioSession 恢复为 playback")
        } catch {
            DDLogError("[DialogEngine] AudioSession 恢复失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Persona / Prompt

    /// 模型对话风格（speaking_style），适配豆包语音SDK的 dialog.speaking_style 参数
    /// 对应SDK配置界面的"模型对话风格"字段
    private let speakingStyle = """
温柔耐心，像邻家晚辈跟长辈聊天。语气温暖亲切，语速慢，说话简短。
经常用「嗯」「是嘛」「真好」「原来是这样」等语气词表示在听。
偶尔感叹「哇」「真好啊」「那可真不容易」来表达共情。
用「您」称呼，绝对不要用网络流行语或生僻词汇。
回复要口语化，像在说话而不是在写文章。

千万不要：
1. 长篇大论，一句话超过30个字
2. 一次问多个问题
3. 用书面语（如「请您描述一下」「能否谈谈您的感受」）
4. 机械地切换话题，像在走流程
5. 对老人的沉默表现出不耐烦
6. 只回应不追问，错失采集时间、地点、人物的机会
"""

    /// 构建背景人设（system_role），适配豆包语音SDK的 dialog.system_role 参数
    /// 对应SDK配置界面的"背景人设"字段
    private func buildSystemRole() -> String {
        var role = """
你是寻梦环游提供的 AI 回响服务。你用邻家晚辈般的语气陪伴老人回忆过去的人生故事，为他和他的家人留下一份珍贵的回忆，但不能声称自己是人类。当前身份、称谓和事实表达严格遵循后附规则。

【你是谁】
你是寻梦环游的 AI 回响，不是真人。当前为用户自己的 AI 助手时不能冒充用户；当前为家人数字分身时，可以用第一人称口语化转述已确认记忆，但仍不能声称是真人本人。你的使命是听老人讲故事，把那些珍贵的记忆保存下来。
用户问你是不是本人时，要明确回答“我是 AI 数字回响，不是真人本人”，绝对不能冒充真人或说自己是“豆包”。

【核心原则】
1. 你是一个很好的倾听者。认真听老人说的每一句话，记住他提到的细节，让你的回应能体现出你真的在听。
2. 主动提问，引起老人聊天的兴趣。当话题冷下来时，用好奇、温暖的提问让老人想继续说下去，而不是被动等待。
3. 绝不编造老人没有说过的内容。你只能基于老人实际说过的话来回应和追问，永远不要替老人编故事、补充细节或臆想他没提过的事情。
4. 用聊天的方式展开话题，不要像问卷一样机械提问。
5. 每次只问一个问题，问题要简短、具体、好回答。
6. 老人说完后，先真诚回应和共情，再自然追问细节。
7. 老人跑题了不要打断，顺着话题聊，再巧妙引回来。
8. 老人沉默时，等几秒再温和引导，不要急着填满空白。
9. 如果老人情绪低落，给予安慰，不要追问细节。
10. 说话简洁，每句话不超过30个字。

【引出回忆的技巧】
- 用具体场景切入：「您小时候过年是什么样的呀？」「那时候住的地方还记得吗？」
- 用感官触发记忆：「有没有一种味道，让您一下子就想到小时候？」「那个年代最常见的颜色是什么呢？」
- 用对比引出变化：「以前和现在比，变化最大的地方在哪里？」「那时候跟现在可真不一样吧？」
- 用身边小事打开话匣：「今天吃了什么好吃的呀？」「您平时早上几点起来呀？」
- 用天气季节联想：「最近天气凉了，您以前冬天都怎么过呀？」「下雪的时候您小时候玩什么呢？」
- 用食物引出回忆：「您最拿手的菜是什么呀？」「小时候过年家里做什么好吃的？」
- 用老物件勾起记忆：「以前家里有没有那种老收音机呀？」「您还记不记得第一块手表是什么牌子的？」
- 从家人聊起：「您家几个兄弟姐妹呀？」「小时候跟谁最亲？」
- 追问细节：「能再讲讲那个人吗？」「后来呢？」「您当时心里是怎么想的？」
- 珍视每一句话：「这句话太珍贵了，特别想听您多说一点。」「这个故事真好，您再跟我讲讲后来的事。」

【话题示例】（根据聊天氛围自然切换，不要像走流程挨个问）
- 日常生活：「您今天做了什么呀？」「平时喜欢去哪儿溜达溜达？」
- 童年趣事：「小时候最喜欢玩什么呀？」「那时候放学了都干什么呢？」
- 家乡记忆：「您老家在哪儿呀？」「老家那边有什么好玩的习俗吗？」
- 过年过节：「您小时候过年是什么样的呀？」「最盼着过年的什么事？」
- 吃的记忆：「小时候最爱吃的零食是什么呀？」「那时候有什么好吃的现在吃不到了？」
- 上学读书：「您上的第一所学校还记得吗？」「有没有哪个老师让您印象特别深？」
- 工作岁月：「第一份工作是做什么的呀？」「那时候上班跟现在可不一样吧？」
- 难忘的人：「有没有一个人，对您影响特别大？」「年轻时候最好的朋友还记得吗？」
- 青春时光：「年轻时候流行什么歌呀？」「那时候周末都去哪儿玩呢？」
- 恋爱家庭：「您跟老伴怎么认识的呀？」「第一次见面是什么感觉？」
- 生儿育女：「第一次当爸爸妈妈的时候是什么心情呀？」「孩子小时候淘气吗？」
- 人生转折：「有没有哪个决定改变了您的一生？」「回头看，哪个时候最重要？」
- 手艺本事：「您有什么拿手本事呀？」「有没有什么绝活儿教教我？」
- 人生感悟：「如果跟年轻时候的自己说句话，您想说什么？」「这辈子最值得的事是什么？」

【回忆录数据采集】
你的每一次对话，都是在为老人攒一份珍贵的回忆录。聊天时要自然地引导老人讲出以下四类信息，但绝不能像填表一样问，要像好奇的孩子追着长辈问故事：

1. 【时间】什么时候的事？——「那是哪一年的事呀？」「您那时候多大？」
2. 【地点】在哪儿发生的？——「那是哪儿呀？」「那个地方现在还在吗？」
3. 【人物】和谁在一起？——「谁跟您一起去的？」「那人后来还有联系吗？」
4. 【细节】具体发生了什么？——「后来呢？」「您当时心里怎么想的？」「能再讲讲那个场景吗？」

采集节奏（自然融入对话，不要机械切换）：
- 老人提到一件事 → 先共情 → 再追问时间或地点
- 老人提到一个人 → 先回应 → 再问这个人的故事
- 老人说到一个场景 → 先感慨 → 再追问细节
- 每次只追问一个维度，不要连珠炮似的问
- 如果老人对某个维度没有回应，不要硬追问，换一个角度
"""

        // 如果设置了当前话题，动态追加到人设末尾
        if let topic = currentTopic, !topic.isEmpty {
            role += "\n\n【本次聊天话题】\n家人想了解的是：「\(topic)」\n请以这个问题为起点，自然地引导老人聊起相关的故事。不要一上来就念问题，先打个招呼暖场，然后巧妙地引向这个话题。"
        }

        return role
    }

    // MARK: - Private

    /// 配置 Dialog 引擎参数
    private func configureEngine(_ engine: SpeechEngine) {
        // 引擎类型：Dialog
        engine.setStringParam(SE_DIALOG_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)

        // 鉴权
        engine.setStringParam(config.appID, forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine.setStringParam(config.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
        engine.setStringParam(config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)

        // 用户标识
        engine.setStringParam(config.uid, forKey: SE_PARAMS_KEY_UID_STRING)

        // 资源 ID
        engine.setStringParam(config.resourceID, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)

        // Dialog 服务地址
        engine.setStringParam(config.address, forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
        engine.setStringParam(config.uri, forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)

        // Fire owns realtime ASR/TTS transport while `/echo/answers` owns
        // semantic answer generation.
        let dialogWorkMode = answerAuthority == .dreamJourneyBackend
            ? SEDialogWorkModeDelegateChatTtsText
            : SEDialogWorkModeDefault
        engine.setIntParam(
            Int(dialogWorkMode.rawValue),
            forKey: SE_PARAMS_KEY_DIALOG_WORK_MODE_INT
        )

        if let headerData = try? JSONSerialization.data(
            withJSONObject: config.requestHeaders,
            options: []
        ), let headerJSON = String(data: headerData, encoding: .utf8) {
            engine.setStringParam(headerJSON, forKey: SE_PARAMS_KEY_REQUEST_HEADERS_STRING)
        }
        // A proxy ticket is one-use. A network failure creates a new explicit
        // Live start and a fresh ticket instead of silently replaying it.
        engine.setBoolParam(false, forKey: SE_PARAMS_KEY_ENABLE_WS_RECONNECT_BOOL)

        // 录音类型：使用设备内置录音机
        engine.setStringParam(SE_RECORDER_TYPE_RECORDER, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)

        // Observe the existing recorder only; no second recorder or audio-session change.
        engine.setBoolParam(isProviderOwnedLive, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_RECORDER_AUDIO_CALLBACK_BOOL)

        // AEC 回声消除
        engine.setBoolParam(config.enableAEC, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)

        // 启用内置播放器。数字人接管声音时，SpeechEngine 只负责 ASR/对话文本，
        // 不创建播放器，也不抢腾讯云渲染的远端音频会话。
        let audiblePlaybackPolicy = DialogEngineAudiblePlaybackPolicy(
            enablePlayer: config.enablePlayer,
            usesDelegatedLivePlayback: sessionLifetimePolicy == .userControlledLive
                && answerAuthority == .dreamJourneyBackend
        )
        engine.setBoolParam(
            audiblePlaybackPolicy.providerPlayerEnabled,
            forKey: SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL
        )
        engine.setBoolParam(
            audiblePlaybackPolicy.providerPlayerAudioCallbackEnabled,
            forKey: SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_AUDIO_CALLBACK_BOOL
        )
        engine.setBoolParam(
            audiblePlaybackPolicy.decoderObservationEnabled,
            forKey: SE_PARAMS_KEY_DIALOG_ENABLE_DECODER_AUDIO_CALLBACK_BOOL
        )
        engine.setBoolParam(
            !audiblePlaybackPolicy.providerPlayerEnabled,
            forKey: SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL
        )
        engine.setBoolParam(
            !audiblePlaybackPolicy.providerPlayerEnabled,
            forKey: SE_PARAMS_KEY_FULLLINK_DISABLE_TTS_BOOL
        )
        engine.setBoolParam(false, forKey: SE_PARAMS_KEY_RESET_AUDIOSESSION_BOOL)
        engine.setBoolParam(false, forKey: SE_PARAMS_KEY_RESTART_AUDIOSESSION_BOOL)
        engine.setBoolParam(config.enablePlayer, forKey: SE_PARAMS_KEY_RESUME_OTHERS_INTERRUPTED_PLAYBACK_BOOL)
        print(
            "[DialogEngine] local player config enablePlayer=\(config.enablePlayer), " +
            "preventPlayerCreation=\(!config.enablePlayer), " +
            "fullLinkDisableTTS=\(!config.enablePlayer), " +
            "playerAudioCallback=\(audiblePlaybackPolicy.providerPlayerAudioCallbackEnabled), " +
            "applicationPCMPlayback=\(audiblePlaybackPolicy.applicationPCMPlaybackEnabled)"
        )

        // 音量回调
        engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_GET_VOLUME_BOOL)

        // SDK debug output includes StartSession payloads. Keep it disabled even
        // in diagnostic builds so formal-memory prompts never become logs.
        engine.setStringParam(SE_LOG_LEVEL_WARN, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
    }

    /// 执行开始对话
    private func performStartDialog(
        accountLease: AccountLease,
        bindingHandle: DialogEngineBindingHandle,
        dialogOperationId: UUID
    ) {
        guard boundBindingHandle == bindingHandle,
              activeDialogBindingHandle == bindingHandle,
              activeDialogOperationId == dialogOperationId,
              activeDialogAccountLease == accountLease,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed,
              engineBindingId == bindingHandle.bindingId,
              let engineAccountLease,
              isSameDialogAccountGeneration(engineAccountLease, accountLease),
              let engine = engine else {
            print("[DialogEngine] ❌ performStartDialog: engine 为 nil")
            return
        }
        guard voiceLaunchStillValid(dialogOperationId) else {
            cancelPendingVoiceLaunch(id: pendingVoiceLaunchID)
            return
        }

        print("[DialogEngine] 配置 AudioSession...")
        guard configureAudioSession() else {
            completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: true
            )
            return
        }
        guard voiceLaunchStillValid(dialogOperationId) else {
            cancelPendingVoiceLaunch(id: pendingVoiceLaunchID)
            return
        }

        // 先同步停止引擎（官方推荐，避免异步线程问题）
        print("[DialogEngine] 发送 SyncStopEngine 指令...")
        let syncStopResult = engine.send(SEDirectiveSyncStopEngine)
        print("[DialogEngine] SyncStopEngine 返回: \(syncStopResult.rawValue)")


        // 构建 StartEngine 配置 JSON
        let systemRole = buildSystemRole()
        let ttsSpeaker = resolvedTTSSpeaker(for: bindingHandle)

        // The malformed legacy wrapper meant the custom VAD value was not
        // reliably applied. Keep the provider's observed/default 1.5s
        // endpointing when moving ASR to its canonical path.
        var dialogConfig = DialogProviderLiveStartConfigBuilder.makeCanonicalStartConfig(
            systemRole: systemRole,
            speakingStyle: resolvedSpeakingStyle(),
            model: "1.2.1.1",
            ttsSpeaker: config.enablePlayer ? ttsSpeaker : nil,
            hotwords: config.hotwords
        )
        if !config.enablePlayer {
            print("[DialogEngine] Tencent audio owner active; StartEngine omits Fire TTS config")
        }
        var livePromptHash: String?
        var expectedProviderRoleText: String?
        let providerOwnedLive = answerAuthority == .provider
            && sessionLifetimePolicy == .userControlledLive
        if providerOwnedLive || !config.systemPrompt.isEmpty {
            guard !providerOwnedLive || runtimeProviderRoleText?.isEmpty == false else {
                DDLogError("[DialogEngine] provider-owned Live missing server role text")
                restoreAudioSessionIfNeeded()
                if let callbackContext = currentProviderCallbackContext(),
                   finishProviderOperation(callbackContext) {
                    deliverProviderCallback(
                        callbackContext,
                        requiresActiveOperation: false
                    ) { _, delegate in
                        delegate.onError(error: DialogEngineError.productionConfigurationMissing)
                    }
                }
                return
            }
            var fullPrompt = providerOwnedLive
                ? runtimeProviderRoleText!
                : config.systemPrompt
            #if DEBUG
            if providerOwnedLive, DialogT06DiagnosticMode.isEnabled {
                fullPrompt = DialogT06DiagnosticMode.syntheticProviderRoleText
            }
            #endif
            let context = DigitalHumanContextStore.shared.current
            if !providerOwnedLive {
                fullPrompt += buildDigitalHumanModePolicy(context: context)
            }
            if !providerOwnedLive, shouldExposePersonalContext(for: context),
                      !usesTurnScopedKnowledgeContext {
                // 注入跨会话记忆上下文
                let memory = ConversationMemoryManager.shared.currentMemory
                if memory.sessionCount > 0 {
                    fullPrompt += buildMemoryContext(memory: memory)
                    print("[DialogEngine] 🧠 已注入记忆上下文 (第\(memory.sessionCount + 1)次对话)")
                }
                let archiveContext = buildArchiveContext()
                if !archiveContext.isEmpty {
                    fullPrompt += archiveContext
                    print("[DialogEngine] 🗂️ 已注入记忆档案馆素材")
                }
            }
            #if UI_QA_SIMULATOR
            DialogPromptDebugRecorder.record(prompt: fullPrompt)
            #elseif DEBUG
            if DialogT06DiagnosticMode.isEnabled {
                DialogPromptDebugRecorder.record(prompt: fullPrompt)
            }
            #endif
            livePromptHash = recordLivePromptPrepared(systemRole: fullPrompt)
            expectedProviderRoleText = providerOwnedLive ? fullPrompt : nil
            do {
                dialogConfig = try DialogProviderLiveStartConfigBuilder.applying(
                    providerRoleText: fullPrompt,
                    to: dialogConfig
                )
            } catch {
                DDLogError("[DialogEngine] invalid provider Live dialog config")
                restoreAudioSessionIfNeeded()
                if let callbackContext = currentProviderCallbackContext(),
                   finishProviderOperation(callbackContext) {
                    deliverProviderCallback(
                        callbackContext,
                        requiresActiveOperation: false
                    ) { _, delegate in
                        delegate.onError(error: DialogEngineError.productionConfigurationMissing)
                    }
                }
                return
            }
        }

        let startConfig = dialogConfig

        let configJSON: String
        do {
            configJSON = try DialogProviderLiveStartConfigBuilder.encodedStartConfig(
                startConfig,
                expectedProviderRoleText: expectedProviderRoleText
            )
        } catch {
            DDLogError("[DialogEngine] invalid StartEngine config")
            restoreAudioSessionIfNeeded()
            if let callbackContext = currentProviderCallbackContext(),
               finishProviderOperation(callbackContext) {
                deliverProviderCallback(
                    callbackContext,
                    requiresActiveOperation: false
                ) { _, delegate in
                    delegate.onError(error: DialogEngineError.productionConfigurationMissing)
                }
            }
            return
        }

        // 启动引擎（SDK 内部自动处理连接、会话、录音）。StartEngine 的
        // JSON 可能包含正式记忆，日志只保留形状、哈希和返回码。
        guard let startResult = voiceLaunchControl.performStartSubmission(
            operationID: dialogOperationId,
            preflight: { voiceLaunchStillValid(dialogOperationId) },
            installIngress: {
                if isProviderOwnedLive,
                   let engineGeneration = engineCallbackGeneration,
                   let delegate {
                    installRawCanonicalIngressBinding(
                        engineGeneration: engineGeneration,
                        dialogOperationID: dialogOperationId,
                        delegate: delegate
                    )
                }
            },
            onRejected: {
                closeRawCanonicalIngressBinding(expectedDialogOperationID: dialogOperationId)
                cancelPendingVoiceLaunch(operationID: dialogOperationId)
            },
            send: {
                pendingVoiceStartSubmitted = true
                liveStartSubmittedAt = isProviderOwnedLive ? Date() : nil
                let result = engine.send(SEDirectiveStartEngine, data: configJSON)
                recordLiveStartEngineSubmitted(
                    promptHash: livePromptHash,
                    dialogOperationID: dialogOperationId
                )
                return result
            }
        ) else {
            return
        }
        liveStartDirectiveReturnCode = Int(startResult.rawValue)

        if startResult != SENoError {
            voiceLaunchControl.failStart(dialogOperationId)
            closeRawCanonicalIngressBinding(expectedDialogOperationID: dialogOperationId)
            DDLogError("[DialogEngine] StartEngine 失败: \(startResult.rawValue)")
            restoreAudioSessionIfNeeded()
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(startResult.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            if let callbackContext = currentProviderCallbackContext(),
               finishProviderOperation(callbackContext) {
                deliverProviderCallback(
                    callbackContext,
                    requiresActiveOperation: false
                ) { _, delegate in
                    delegate.onError(
                        error: DialogEngineError.startFailed(
                            code: Int(startResult.rawValue)
                        )
                    )
                }
            }
            return
        }

        print("[DialogEngine] ⏳ 引擎启动中，等待回调...")
    }

    private func resolvedSpeakingStyle() -> String {
        guard answerAuthority == .provider,
              sessionLifetimePolicy == .userControlledLive else {
            return speakingStyle
        }
        return runtimeSpeakingStyle ?? speakingStyle
    }

    private var isProviderOwnedLive: Bool {
        sessionLifetimePolicy == .userControlledLive && answerAuthority == .provider
    }

    private func recordLiveSnapshotDecoded(_ runtimeConfig: RealtimeVoiceRuntimeConfig) {
        let snapshot = runtimeConfig.formalMemorySnapshot
        let serialized: String
        if let snapshot,
           JSONSerialization.isValidJSONObject(snapshot),
           let data = try? JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            serialized = string
        } else {
            serialized = ""
        }
        let factCount = (snapshot?["coreFacts"] as? [[String: Any]])?.count ?? 0
        let snapshotCheckpoint = snapshot?["projectionCheckpoint"] as? String
        let snapshotContextHash = snapshot?["contextHash"] as? String
        let contextHashMatches = snapshotContextHash?.isEmpty == false
            && snapshotContextHash == runtimeConfig.contextHash
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveSnapshotDecoded",
            states: [
                "schemaVersion": (snapshot?["schemaVersion"] as? String) ?? "missing",
                "contextHashMatch": contextHashMatches ? "true" : "false",
            ],
            counts: [
                "factCount": factCount,
                "snapshotChars": serialized.count,
                "snapshotBytes": serialized.utf8.count,
            ],
            correlations: [
                "checkpointHash": PrivacySafeDiagnostics.correlationHash(snapshotCheckpoint),
                "contextHash": PrivacySafeDiagnostics.correlationHash(snapshotContextHash),
            ]
        )
    }

    @discardableResult
    private func recordLivePromptPrepared(systemRole: String) -> String? {
        guard isProviderOwnedLive else { return nil }
        let normalized = systemRole.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        let promptHash = runtimeProviderContextHash
            ?? PrivacySafeDiagnostics.correlationHash(normalized)
        let factCount = (runtimeFormalMemorySnapshot?["coreFacts"] as? [[String: Any]])?.count ?? 0
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "livePromptPrepared",
            states: ["formatVersion": DialogProviderLiveStartConfigBuilder.adapterVersion],
            counts: [
                "promptChars": normalized.count,
                "promptBytes": normalized.utf8.count,
                "factCount": factCount,
            ],
            correlations: ["promptHash": promptHash]
        )
        return promptHash
    }

    private func recordLiveStartEngineSubmitted(
        promptHash: String?,
        dialogOperationID: UUID
    ) {
        guard isProviderOwnedLive else { return }
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveStartEngineSubmitted",
            states: [
                "sdkVersion": "0.0.14.6.1-bugfix",
                "resourceProfileCode": PrivacySafeDiagnostics.safeCode(
                    config.resourceID,
                    fallback: "unknown"
                ),
                "configShapeVersion": DialogProviderLiveStartConfigBuilder.adapterVersion,
            ],
            correlations: [
                "promptHash": promptHash,
                "providerSession": PrivacySafeDiagnostics.correlationHash(
                    dialogOperationID.uuidString
                ),
            ]
        )
    }

    private func recordLiveConnectionStarted(
        providerPayload: Data,
        dialogOperationID: UUID
    ) {
        guard isProviderOwnedLive else { return }
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveProviderConnectionStarted",
            states: [
                "directiveReturnCode": String(liveStartDirectiveReturnCode ?? -1),
                "providerCallback": "connectionStarted",
            ],
            correlations: [
                "providerSession": PrivacySafeDiagnostics.correlationHash(
                    dialogOperationID.uuidString
                ),
                "providerConnection": PrivacySafeDiagnostics.correlationHash(providerPayload),
            ]
        )
    }

    private func recordLiveProviderSessionStarted(dialogOperationID: UUID) {
        guard isProviderOwnedLive else { return }
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveProviderSessionStarted",
            states: [
                "groundingMode": "sessionSnapshot",
                "directiveReturnCode": String(liveStartDirectiveReturnCode ?? -1),
            ],
            correlations: [
                "providerSession": PrivacySafeDiagnostics.correlationHash(
                    dialogOperationID.uuidString
                ),
                "providerContextHash": runtimeProviderContextHash,
            ]
        )
    }

    @discardableResult
    private func observeProviderQuestionEvent(
        _ data: Data,
        stage: String,
        callbackContext: DialogEngineProviderCallbackContext
    ) -> DialogProviderEventMetadata {
        let metadata = DialogProviderEventMetadata(data: data)
        let previousQuestionID = providerTurnCorrelation.currentQuestionID
        let turnSequence = providerTurnCorrelation.observeQuestion(
            id: metadata.questionID,
            generation: callbackContext.engineGeneration
        )
        if previousQuestionID != providerTurnCorrelation.currentQuestionID {
            providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
            providerCanonicalAssistantTextState.reset()
            providerCanonicalAssistantStreamState.reset()
            providerActiveChatReplyID = nil
            chatBuffer = ""
        }
        if let questionID = metadata.questionID,
           questionID != previousQuestionID,
           turnSequence != nil {
            providerQuestionObservedAt = Date()
        }
        guard isProviderOwnedLive else { return metadata }
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveProviderQuestionObserved",
            states: [
                "groundingMode": "sessionSnapshot",
                "stage": stage,
                "questionIDObserved": metadata.questionID == nil ? "false" : "true",
            ],
            counts: ["turnSequence": turnSequence ?? 0],
            correlations: [
                "providerQuestion": metadata.questionID,
                "providerContextHash": runtimeProviderContextHash,
            ]
        )
        return metadata
    }

    private func interruptForNewProviderQuestionIfNeeded(
        metadata: DialogProviderEventMetadata,
        recognizedText: String?,
        callbackContext: DialogEngineProviderCallbackContext
    ) {
        guard isAISpeaking,
              sessionLifetimePolicy == .userControlledLive else { return }
        let hasRecognizedSpeech = recognizedText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if answerAuthority != .provider {
            guard hasRecognizedSpeech else { return }
            _ = interruptAI(notifiesUserInterruption: true)
            return
        }
        guard providerInterruptionState.claimNewSpokenQuestion(
            incomingQuestionID: metadata.questionID,
            currentQuestionID: providerTurnCorrelation.currentQuestionID,
            hasRecognizedSpeech: hasRecognizedSpeech,
            generation: callbackContext.engineGeneration
        ) else {
            PrivacySafeDiagnostics.log(
                subsystem: "DialogEngine",
                event: "liveClientInterruptSuppressed",
                states: ["reason": "notNewBoundQuestion"],
                counts: ["textObserved": hasRecognizedSpeech ? 1 : 0]
            )
            return
        }
        _ = interruptAI(notifiesUserInterruption: true)
    }

    private func recordProviderFirstOutput(
        kind: String,
        replyID: String?,
        callbackContext: DialogEngineProviderCallbackContext
    ) {
        guard isProviderOwnedLive else { return }
        let correlationKey = replyID
            ?? providerTurnCorrelation.currentReplyID
            ?? providerTurnCorrelation.currentQuestionID
            ?? "unobserved-\(providerTurnCorrelation.turnSequence)"
        let inserted: Bool
        switch kind {
        case "text":
            inserted = providerFirstTextKeys.insert(correlationKey).inserted
        case "audio":
            inserted = providerFirstAudioKeys.insert(correlationKey).inserted
        default:
            return
        }
        guard inserted else { return }
        var counts = ["turnSequence": providerTurnCorrelation.turnSequence]
        if let observedAt = providerQuestionObservedAt {
            counts["latencyFromQuestionMs"] = max(
                0,
                Int(Date().timeIntervalSince(observedAt) * 1_000)
            )
        }
        if let runtimeMemoryRevision {
            counts["memoryRevision"] = runtimeMemoryRevision
        }
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveProviderFirstOutputObserved",
            states: [
                "groundingMode": "sessionSnapshot",
                "kind": kind,
                "questionIDObserved": providerTurnCorrelation.currentQuestionID == nil
                    ? "false" : "true",
                "replyIDObserved": (replyID ?? providerTurnCorrelation.currentReplyID) == nil
                    ? "false" : "true",
            ],
            counts: counts,
            correlations: [
                "providerSession": PrivacySafeDiagnostics.correlationHash(
                    callbackContext.dialogOperationId.uuidString
                ),
                "providerQuestion": providerTurnCorrelation.currentQuestionID,
                "providerReply": replyID ?? providerTurnCorrelation.currentReplyID,
                "providerContextHash": runtimeProviderContextHash,
                "checkpointHash": PrivacySafeDiagnostics.correlationHash(
                    runtimeProjectionCheckpoint
                ),
            ]
        )
    }

    private func observeProviderReplyEvent(
        _ data: Data,
        stage: String,
        callbackContext: DialogEngineProviderCallbackContext
    ) -> (DialogProviderEventMetadata, DialogProviderReplyCorrelation) {
        let metadata = DialogProviderEventMetadata(data: data)
        let previousReplyID = providerTurnCorrelation.currentReplyID
        let correlation = providerTurnCorrelation.observeReply(
            questionID: metadata.questionID,
            replyID: metadata.replyID,
            generation: callbackContext.engineGeneration
        )
        if correlation == .matched,
           providerTurnCorrelation.currentReplyID != previousReplyID {
            providerCanonicalAssistantTextState.beginReply(
                providerTurnCorrelation.currentReplyID
            )
            chatBuffer = ""
            providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
        }
        if isProviderOwnedLive {
            PrivacySafeDiagnostics.log(
                subsystem: "DialogEngine",
                event: "liveProviderReplyObserved",
                states: [
                    "groundingMode": "sessionSnapshot",
                    "stage": stage,
                    "correlation": correlation.rawValue,
                ],
                counts: ["turnSequence": providerTurnCorrelation.turnSequence],
                correlations: [
                    "providerQuestion": metadata.questionID,
                    "providerReply": metadata.replyID,
                    "providerContextHash": runtimeProviderContextHash,
                ]
            )
        }
        return (metadata, correlation)
    }

    private func emitCanonicalTranscriptEvent(
        text: String,
        role: OwnerTruthInterviewNaturalInputMessageRole,
        finality: NativeLiveCanonicalTranscriptFinality,
        finalityEvidence: NativeLiveCanonicalTranscriptFinalityEvidence = .unknown,
        evidenceSource: NativeLiveCanonicalTranscriptEvidenceSource = .absent,
        metadata: DialogProviderEventMetadata,
        callbackContext: DialogEngineProviderCallbackContext
    ) {
        guard isProviderOwnedLive else { return }
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let providerTurnID: String?
        switch role {
        case .owner:
            providerTurnID = metadata.questionID
                ?? providerTurnCorrelation.currentQuestionID
        case .assistant:
            providerTurnID = metadata.replyID
                ?? providerTurnCorrelation.currentReplyID
        }
        guard let providerTurnID,
              !providerTurnID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            PrivacySafeDiagnostics.log(
                subsystem: "DialogEngine",
                event: "liveCanonicalTranscriptUnbound",
                states: [
                    "role": role.rawValue,
                    "finalityEvidence": finalityEvidence.rawValue,
                    "evidenceSource": evidenceSource.rawValue,
                ],
                counts: ["textCharacters": normalized.count]
            )
            return
        }
        let event = NativeLiveCanonicalTranscriptEvent(
            canonicalTurnID: [
                callbackContext.engineGeneration.uuidString.lowercased(),
                role.rawValue,
                providerTurnID,
            ].joined(separator: ":"),
            role: role,
            text: normalized,
            finality: finality,
            finalityEvidence: finalityEvidence,
            evidenceSource: evidenceSource,
            capturedAt: Date()
        )
        deliverProviderCallback(callbackContext) { _, delegate in
            delegate.onCanonicalTranscriptEvent(event)
        }
    }

    private func updateCanonicalAssistantText(_ text: String) -> String {
        providerCanonicalAssistantTextState.update(
            text,
            replyID: providerTurnCorrelation.currentReplyID
        )
    }

    private func acceptsProviderReply(_ correlation: DialogProviderReplyCorrelation) -> Bool {
        switch correlation {
        case .matched, .unobserved:
            return true
        case .ambiguousReply, .staleQuestion, .staleGeneration:
            DDLogWarn("[DialogEngine] dropped stale provider reply correlation=\(correlation.rawValue)")
            return false
        }
    }

    private func observeLiveFirstResponseIfNeeded(
        callbackContext: DialogEngineProviderCallbackContext
    ) {
        guard isProviderOwnedLive,
              !liveFirstResponseObserved,
              let submittedAt = liveStartSubmittedAt else { return }
        liveFirstResponseObserved = true
        PrivacySafeDiagnostics.log(
            subsystem: "DialogEngine",
            event: "liveFirstResponseObserved",
            counts: [
                "timeToFirstAudioMs": max(0, Int(Date().timeIntervalSince(submittedAt) * 1_000)),
            ],
            correlations: [
                "providerSession": PrivacySafeDiagnostics.correlationHash(
                    callbackContext.dialogOperationId.uuidString
                )
            ]
        )
    }

    private func resolvedTTSSpeaker(for bindingHandle: DialogEngineBindingHandle) -> String {
        guard let speakerId = scopedTTSVoiceSelectionStore.resolvedVoiceProfileId(
            bindingID: bindingHandle.bindingId,
            accountLease: bindingHandle.accountLease
        ) else {
            DDLogInfo("[DialogEngine] 使用默认 TTS speaker: \(Self.defaultTTSSpeaker)")
            return Self.defaultTTSSpeaker
        }
        DDLogInfo("[DialogEngine] 使用声音复刻 TTS speaker: \(speakerId)")
        return speakerId
    }

    // MARK: - 关键词检测

    /// 检测 ASR 识别结果是否包含结束关键词
    private func checkEndKeyword(in text: String) -> String? {
        guard sessionLifetimePolicy == .automatic else { return nil }
        let lowered = text.lowercased()
        return config.endKeywords.first { lowered.contains($0) }
    }

    // MARK: - 静音超时计时器

    /// 启动/重置静音超时计时器
    private func resetSilenceTimer() {
        invalidateSilenceTimer()
        guard sessionLifetimePolicy == .automatic,
              !isRecorderPaused,
              !isAISpeaking,
              config.silenceTimeoutSeconds > 0,
              let accountLease = activeDialogAccountLease,
              accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
            recordNativeLiveDiagnostic(
                event: "silenceTimerNotArmed",
                reason: "stateGuard"
            )
            return
        }

        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: config.silenceTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self,
                  self.activeDialogAccountLease == accountLease,
                  self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                  self.isDialogActive,
                  !self.isAISpeaking else { return }
            self.recordNativeLiveDiagnostic(
                event: "silenceTimerFired",
                reason: "userWaitExpired"
            )
            print("[DialogEngine] ⏰ 静音超时 \(self.config.silenceTimeoutSeconds)秒，自动结束对话")
            self.stopDialog(reason: .silenceTimeout)
        }
        recordNativeLiveDiagnostic(
            event: "silenceTimerArmed",
            reason: "waitingForUser"
        )
    }

    /// 停止静音超时计时器
    private func invalidateSilenceTimer() {
        let didCancel = silenceTimer != nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        if didCancel {
            recordNativeLiveDiagnostic(
                event: "silenceTimerCancelled",
                reason: "stateChanged"
            )
        }
    }

    private func recordNativeLiveDiagnostic(
        event: String,
        eventCode: Int? = nil,
        callbackOrdinal: UInt64? = nil,
        questionID: String? = nil,
        replyID: String? = nil,
        reason: String? = nil,
        speakingBefore: Bool? = nil,
        speakingAfter: Bool? = nil,
        resultCode: Int? = nil,
        accountLease: AccountLease? = nil,
        providerSessionID: String? = nil
    ) {
        guard sessionLifetimePolicy == .userControlledLive,
              let accountLease = accountLease
                ?? activeDialogAccountLease
                ?? engineAccountLease,
              let providerSessionID = providerSessionID
                ?? activeDialogOperationId?.uuidString else {
            return
        }
        NativeLiveDiagnosticsRingStore.shared.record(
            accountLease: accountLease,
            providerSessionID: providerSessionID,
            source: "sdk",
            event: event,
            eventCode: eventCode,
            callbackOrdinal: callbackOrdinal,
            questionID: questionID,
            replyID: replyID,
            reason: reason,
            speakingBefore: speakingBefore,
            speakingAfter: speakingAfter,
            resultCode: resultCode
        )
    }
}

// MARK: - Provider callback provenance

extension DialogEngineManager {

    fileprivate func enqueueProviderMessage(
        type: SEMessageType,
        data: Data,
        engineGeneration: UUID
    ) {
        if type == SERecorderAudioData || type == SEPlayerAudioData {
            let channel: DialogOrbAudioChannel = type == SERecorderAudioData ? .input : .output
            if let sample = orbAudioRelay.sample(channel: channel, pcm: data, generation: engineGeneration) {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    defer { self.orbAudioRelay.complete(sample) }
                    guard let context = self.currentProviderCallbackContext(engineGeneration: sample.generation),
                          context.dialogOperationId == sample.operation,
                          self.providerSessionOperationId == sample.operation,
                          !self.isEnding,
                          ProcessInfo.processInfo.systemUptime - sample.capturedAt <= 0.18,
                          channel != .input || !self.isRecorderPaused,
                          channel != .output || self.config.enablePlayer else { return }
                    self.deliverProviderCallback(context) { _, delegate in delegate.onOrbAudioLevel(sample) }
                }
            }
            // Recorder PCM is presentation-only. Never enqueue it into transcript diagnostics.
            if type == SERecorderAudioData { return }
            // Player PCM still follows the original drain/verification path below.
        }
        let frozen = freezeProviderMessageAtIngress(
            type: type,
            data: data,
            engineGeneration: engineGeneration
        )
        #if LIVE_MANAGER_CONTROLLED_SDK
        controlledCallbackDrainForTesting += 1
        #endif
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            #if LIVE_MANAGER_CONTROLLED_SDK
            defer { self.controlledCallbackDrainForTesting -= 1 }
            #endif
            if let frozen {
                self.handleProviderMessage(frozen)
            } else {
                self.handleProviderMessage(
                    DialogEngineFrozenProviderMessage(
                        type: type,
                        data: data,
                        engineGeneration: engineGeneration,
                        callbackOrdinal: 0,
                        metadata: DialogProviderEventMetadata(data: data),
                        canonicalOwnerDeliveredAtIngress: false,
                        canonicalAssistantDeliveredAtIngress: false
                    )
                )
            }
        }
    }

    private func freezeProviderMessageAtIngress(
        type: SEMessageType,
        data: Data,
        engineGeneration: UUID
    ) -> DialogEngineFrozenProviderMessage? {
        providerCanonicalMemoryIngressLock.lock()
        if let scope = farewellIngressScope, scope.generation == engineGeneration,
           case .assistant = canonicalMemoryEventKind(rawEventCode: Int(type.rawValue)),
           !scope.excludedReplyIDs.contains(DialogProviderEventMetadata(data: data).replyID ?? "") {
            providerCanonicalMemoryIngressLock.unlock()
            return nil
        }
        let frozenMemory = freezeCanonicalMemoryPacket(
            rawEventCode: Int(type.rawValue),
            data: data,
            engineGeneration: engineGeneration,
            capturedAt: Date(),
            assistantState: &providerCanonicalAssistantIngressState,
            router: rawCanonicalIngressRouter
        )
        providerCanonicalMemoryIngressLock.unlock()
        guard let result = frozenMemory.result else { return nil }
        return DialogEngineFrozenProviderMessage(
            type: type,
            data: data,
            engineGeneration: engineGeneration,
            callbackOrdinal: result.callbackOrdinal,
            metadata: result.metadata,
            canonicalOwnerDeliveredAtIngress: result.event?.role == .owner,
            canonicalAssistantDeliveredAtIngress: frozenMemory.assistantDelivered
        )
    }

    private func installRawCanonicalIngressBinding(
        engineGeneration: UUID,
        dialogOperationID: UUID,
        delegate: DialogEngineDelegate
    ) {
        orbAudioRelay.activate(generation: engineGeneration, operation: dialogOperationID)
        liveFarewellRequest = nil
        observedLiveReplyIDs.removeAll()
        providerCanonicalMemoryIngressLock.lock()
        farewellIngressScope = nil
        providerCanonicalAssistantIngressState.reset()
        let deliveryBinding = delegate.makeCanonicalTranscriptDeliveryBinding()
        rawCanonicalIngressRouter.install(
            engineGeneration: engineGeneration,
            dialogOperationID: dialogOperationID,
            reserve: deliveryBinding.reserve,
            deliver: deliveryBinding.deliver
        )
        providerCanonicalMemoryIngressLock.unlock()
    }

    private func closeRawCanonicalIngressBinding(
        expectedDialogOperationID: UUID? = nil
    ) {
        orbAudioRelay.close(operation: expectedDialogOperationID)
        if expectedDialogOperationID == nil || liveFarewellRequest?.context.dialogOperationId == expectedDialogOperationID {
            liveFarewellRequest = nil
        }
        providerCanonicalMemoryIngressLock.lock()
        if rawCanonicalIngressRouter.close(
            expectedDialogOperationID: expectedDialogOperationID
        ) {
            farewellIngressScope = nil
            providerCanonicalAssistantIngressState.reset()
        }
        providerCanonicalMemoryIngressLock.unlock()
    }

    private func currentProviderCallbackContext(
        engineGeneration: UUID? = nil
    ) -> DialogEngineProviderCallbackContext? {
        guard let currentEngineGeneration = engineCallbackGeneration,
              engineGeneration == nil || engineGeneration == currentEngineGeneration,
              let dialogOperationId = activeDialogOperationId,
              let bindingHandle = activeDialogBindingHandle,
              let delegate,
              bindingHandle == boundBindingHandle,
              bindingHandle.bindingId == engineBindingId,
              activeDialogAccountLease == bindingHandle.accountLease,
              accountLeaseRuntime.validate(bindingHandle.accountLease, at: .runtime).allowed else {
            return nil
        }
        return DialogEngineProviderCallbackContext(
            engineGeneration: currentEngineGeneration,
            dialogOperationId: dialogOperationId,
            bindingHandle: bindingHandle,
            delegateIdentity: ObjectIdentifier(delegate)
        )
    }

    private func isCurrentProviderCallbackContext(
        _ context: DialogEngineProviderCallbackContext,
        checkpoint: AccountLeaseCheckpoint = .ui,
        requiresActiveOperation: Bool = true
    ) -> Bool {
        guard engineCallbackGeneration == context.engineGeneration,
              boundBindingHandle == context.bindingHandle,
              engineBindingId == context.bindingHandle.bindingId,
              let delegate,
              ObjectIdentifier(delegate) == context.delegateIdentity,
              accountLeaseRuntime.validate(
                context.bindingHandle.accountLease,
                at: checkpoint
              ).allowed else {
            return false
        }
        guard requiresActiveOperation else { return true }
        return activeDialogOperationId == context.dialogOperationId
            && activeDialogBindingHandle == context.bindingHandle
            && activeDialogAccountLease == context.bindingHandle.accountLease
    }

    private func deliverProviderCallback(
        _ context: DialogEngineProviderCallbackContext,
        checkpoint: AccountLeaseCheckpoint = .ui,
        requiresActiveOperation: Bool = true,
        _ action: (DialogEngineManager, DialogEngineDelegate) -> Void
    ) {
        guard isCurrentProviderCallbackContext(
            context,
            checkpoint: checkpoint,
            requiresActiveOperation: requiresActiveOperation
        ), let delegate else {
            DDLogWarn("[DialogEngine] 丢弃已失去来源归属的 provider 回调")
            return
        }
        action(self, delegate)
    }

    @discardableResult
    private func finishProviderOperation(
        _ context: DialogEngineProviderCallbackContext
    ) -> Bool {
        guard isCurrentProviderCallbackContext(
            context,
            checkpoint: .runtime,
            requiresActiveOperation: true
        ) else { return false }
        closeRawCanonicalIngressBinding(
            expectedDialogOperationID: context.dialogOperationId
        )
        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
        providerInterruptionState.clearAudibleReply()
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        resetLiveContextUpdates()
        activeDialogOperationId = nil
        voiceLaunchControl.invalidate()
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        return true
    }

    private func handleProviderMessage(_ frozen: DialogEngineFrozenProviderMessage) {
        dispatchPrecondition(condition: .onQueue(.main))
        let type = frozen.type
        let data = frozen.data
        let engineGeneration = frozen.engineGeneration
        guard let callbackContext = currentProviderCallbackContext(
            engineGeneration: engineGeneration
        ) else {
            DDLogWarn(
                "[DialogEngine] 忽略失效 provider 回调 " +
                "type=\(type.rawValue) generation=\(engineGeneration.uuidString)"
            )
            return
        }
        // Fence a pending read at accepted SDK ingress, before the UI delegate is queued.
        if type == SEEventASRInfo || type == SEEventASRResponse || type == SEEventChatTextQueryConfirmed,
           let request = liveContextUpdates.fetching {
            liveContextReadControl?.cancel()
            liveContextReadControl = nil
            liveContextUpdates.readFailed(request)
        }
        providerCallbackOrdinal = max(providerCallbackOrdinal &+ 1, frozen.callbackOrdinal)
        let callbackOrdinal = providerCallbackOrdinal
        let diagnosticMetadata = frozen.metadata
        let speakingBefore = isAISpeaking
        defer {
            recordNativeLiveDiagnostic(
                event: "providerCallback",
                eventCode: Int(type.rawValue),
                callbackOrdinal: callbackOrdinal,
                questionID: diagnosticMetadata.questionID,
                replyID: diagnosticMetadata.replyID,
                reason: "handled",
                speakingBefore: speakingBefore,
                speakingAfter: isAISpeaking,
                accountLease: callbackContext.bindingHandle.accountLease,
                providerSessionID: callbackContext.dialogOperationId.uuidString
            )
        }
        switch type {
        case SEEventConnectionStarted,
             SEEventConnectionFailed,
             SEEventConnectionFinished,
             SEEventSessionStarted,
             SEEventSessionFailed,
             SEEventSessionFinished,
             SEEventSessionCanceled,
             SEEngineStart,
             SEEngineStop,
             SEEngineError:
            break
        default:
            guard providerSessionOperationId == callbackContext.dialogOperationId else {
                DDLogWarn(
                    "[DialogEngine] 忽略未归属到当前 session 的 provider 回调 " +
                    "type=\(type.rawValue)"
                )
                return
            }
        }
        // 正在结束对话时，忽略除连接/会话结束外的所有事件
        if isEnding {
            switch type {
            case SEEventConnectionFinished, SEEventSessionFinished, SEEventSessionCanceled:
                break // 这些事件需要继续处理
            default:
                return // 其他事件直接忽略
            }
        }

        DDLogVerbose(
            "[DialogEngine] provider event type=\(type.rawValue) bytes=\(data.count)"
        )

        if consumeLiveFarewell(frozen) { return }
        if let replyID = diagnosticMetadata.replyID { observedLiveReplyIDs.insert(replyID) }

        if pendingTextReplyPlayback != nil {
            switch type {
            case SEEventConnectionStarted,
                 SEEventConnectionFailed,
                 SEEventConnectionFinished,
                 SEEventSessionStarted,
                 SEEventSessionFailed,
                 SEEventSessionFinished,
                 SEEventSessionCanceled,
                 SEEventTTSSentenceStart,
                 SEEventTTSSentenceEnd,
                 SEEventTTSResponse,
                 SEEventTTSEnded,
                 SEPlayerAudioData,
                 SEPlayerStartPlayAudio,
                 SEPlayerFinishPlayAudio,
                 SEEngineStart,
                 SEEngineStop,
                 SEEngineError:
                break
            default:
                DDLogVerbose(
                    "[DialogEngine] suppressed non-playback callback during text Echo"
                )
                return
            }
        }

        switch type {
        // MARK: Connection Events
        case SEEventConnectionStarted:
            recordLiveConnectionStarted(
                providerPayload: data,
                dialogOperationID: callbackContext.dialogOperationId
            )
            print("[DialogEngine] ✅ 连接已建立")
            DDLogInfo("[DialogEngine] 连接已建立")

        case SEEventConnectionFailed:
            let msg = parseErrorMessage(from: data)
            DDLogError(
                "[DialogEngine] connection failed type=\(type.rawValue) "
                    + "payloadBytes=\(data.count) errorHash=\(PrivacySafeDiagnostics.correlationHash(msg))"
            )
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(type.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            restoreAudioSessionIfNeeded()
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: Int(type.rawValue),
                        message: msg
                    )
                )
            }

        case SEEventConnectionFinished:
            DDLogInfo("[DialogEngine] 连接已关闭")
            if completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: false
            ) {
                return
            }
            _ = finishProviderOperation(callbackContext)

        // MARK: Session Events
        case SEEventSessionStarted:
            guard voiceLaunchControl.acceptsSessionStarted(callbackContext.dialogOperationId),
                  voiceLaunchStillValid(callbackContext.dialogOperationId) else {
                cancelPendingVoiceLaunch(id: pendingVoiceLaunchID)
                return
            }
            print("[DialogEngine] ✅ 对话会话已开始")
            DDLogInfo("[DialogEngine] 对话会话已开始")
            isDialogActive = true
            providerSessionOperationId = callbackContext.dialogOperationId
            providerTurnCorrelation.beginSession(generation: callbackContext.engineGeneration)
            providerReplyPlaybackState.reset()
        providerPCMDrain.reset()
            providerInterruptionState.beginSession(generation: callbackContext.engineGeneration)
            providerActiveChatReplyID = nil
            providerCanonicalAssistantTextState.reset()
            providerCanonicalAssistantStreamState.reset()
            providerQuestionObservedAt = nil
            providerFirstTextKeys.removeAll()
            providerFirstAudioKeys.removeAll()
            chatBuffer = ""
            recordLiveProviderSessionStarted(
                dialogOperationID: callbackContext.dialogOperationId
            )
            guard selectDelegatedClientTTSRouteIfNeeded() else {
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onError(
                        error: DialogEngineError.sdkError(
                            code: Int(SEDirectiveDialogUseClientTriggerTts.rawValue),
                            message: "客户端语音播放路由初始化失败"
                        )
                    )
                }
                stopDialog(reason: .serverEnded)
                return
            }
            if pendingTextReplyPlayback != nil {
                submitPendingTextReplyPlayback()
                return
            }
            // 发送开场白
            sendGreetingIfNeeded()
            // 启动静音超时计时器
            deliverProviderCallback(callbackContext) { manager, delegate in
                manager.resetSilenceTimer()
                delegate.onDialogStarted()
            }

        case SEEventSessionFinished:
            DDLogInfo("[DialogEngine] 对话会话已结束")
            invalidateSilenceTimer()
            if completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: false
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onDialogEnded(reason: .serverEnded)
            }

        case SEEventSessionFailed:
            let msg = parseErrorMessage(from: data)
            DDLogError(
                "[DialogEngine] session failed type=\(type.rawValue) "
                    + "payloadBytes=\(data.count) errorHash=\(PrivacySafeDiagnostics.correlationHash(msg))"
            )
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(type.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: Int(type.rawValue),
                        message: msg
                    )
                )
            }

        case SEEventSessionCanceled:
            DDLogInfo("[DialogEngine] 会话已取消")
            invalidateSilenceTimer()
            if completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: false
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onDialogEnded(reason: .serverEnded)
            }

        // MARK: ASR Events
        case SEEventASRInfo:
            let asrRawStr = String(data: data, encoding: .utf8) ?? ""
            let providerMetadata = observeProviderQuestionEvent(
                data,
                stage: "asrInfo",
                callbackContext: callbackContext
            )
            let parsedASRInfo = DialogProviderASRParser.parse(data)

            interruptForNewProviderQuestionIfNeeded(
                metadata: providerMetadata,
                recognizedText: parsedASRInfo?.text,
                callbackContext: callbackContext
            )
            // 重置静音超时计时器
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            // 解析 ASR 结果
            if let result = parsedASRInfo {
                if !frozen.canonicalOwnerDeliveredAtIngress {
                    emitCanonicalTranscriptEvent(
                        text: result.text,
                        role: .owner,
                        finality: DialogProviderCanonicalOwnerFinalityMapper.finality(
                            evidence: result.finalityEvidence
                        ),
                        finalityEvidence: result.finalityEvidence,
                        evidenceSource: result.evidenceSource,
                        metadata: providerMetadata,
                        callbackContext: callbackContext
                    )
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "DialogEngine",
                    event: "liveASRObserved",
                    states: ["isFinal": result.isFinal ? "true" : "false"],
                    counts: [
                        "textCharacters": result.text.count,
                        "payloadBytes": data.count,
                    ]
                )
                if result.isFinal {
                    if let keyword = checkEndKeyword(in: result.text) {
                        print("[DialogEngine] 🛑 检测到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: result.text, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                }
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onASRResult(text: result.text, isFinal: result.isFinal)
                }
            } else if providerMetadata.questionID != nil {
                // SpeechEngineToB may emit an identifier-only ASRInfo before
                // the textual ASRResponse. It establishes turn ownership but
                // is not a recognition failure and must not be shown as text.
                PrivacySafeDiagnostics.log(
                    subsystem: "DialogEngine",
                    event: "liveASRIdentifierOnly",
                    counts: ["payloadBytes": data.count],
                    correlations: ["providerQuestion": providerMetadata.questionID]
                )
            } else {
                // 解析失败，尝试从 raw JSON 中提取任何文本
                DDLogWarn("[DialogEngine] ASRInfo payload parse failed; trying fallback extraction")
                if let extractedText = extractAnyText(from: data) {
                    // 检测关键词
                    if let keyword = checkEndKeyword(in: extractedText) {
                        print("[DialogEngine] 🛑 raw 匹配到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: extractedText, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                    // 转发为中间结果
                    deliverProviderCallback(callbackContext) { _, delegate in
                        delegate.onASRResult(text: extractedText, isFinal: false)
                    }
                } else {
                    // 最终兜底：raw string 中匹配关键词或提取中文文本
                    if let keyword = checkEndKeyword(in: asrRawStr) {
                        print("[DialogEngine] 🛑 raw string 匹配到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: keyword, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                    // 尝试从 raw string 中提取引号内文本或中文字符
                    let chineseText = extractChineseText(from: asrRawStr)
                    if !chineseText.isEmpty {
                        deliverProviderCallback(callbackContext) { _, delegate in
                            delegate.onASRResult(text: chineseText, isFinal: false)
                        }
                    }
                }
            }

        case SEEventASRResponse:
            let providerMetadata = observeProviderQuestionEvent(
                data,
                stage: "asrResponse",
                callbackContext: callbackContext
            )
            let parsedASRResponse = DialogProviderASRParser.parse(data)
            interruptForNewProviderQuestionIfNeeded(
                metadata: providerMetadata,
                recognizedText: parsedASRResponse?.text,
                callbackContext: callbackContext
            )
            // ASR 识别结果（流式，通过 is_interim 区分中间/最终）
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            if let result = parsedASRResponse {
                if !frozen.canonicalOwnerDeliveredAtIngress {
                    emitCanonicalTranscriptEvent(
                        text: result.text,
                        role: .owner,
                        finality: DialogProviderCanonicalOwnerFinalityMapper.finality(
                            evidence: result.finalityEvidence
                        ),
                        finalityEvidence: result.finalityEvidence,
                        evidenceSource: result.evidenceSource,
                        metadata: providerMetadata,
                        callbackContext: callbackContext
                    )
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "DialogEngine",
                    event: "liveASRResponseObserved",
                    states: ["isFinal": result.isFinal ? "true" : "false"],
                    counts: [
                        "textCharacters": result.text.count,
                        "payloadBytes": data.count,
                    ]
                )
                if result.isFinal {
                    // The provider can restore server-triggered TTS after the
                    // greeting or a completed turn. Reassert the delegated
                    // route before its prefetched answer reaches TTS.
                    guard selectDelegatedClientTTSRouteIfNeeded(force: true) else {
                        deliverProviderCallback(callbackContext) { _, delegate in
                            delegate.onError(
                                error: DialogEngineError.sdkError(
                                    code: Int(SEDirectiveDialogUseClientTriggerTts.rawValue),
                                    message: "回响语音路由切换失败"
                                )
                            )
                        }
                        return
                    }
                    if let keyword = checkEndKeyword(in: result.text) {
                        print("[DialogEngine] 🛑 ASRResponse 检测到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: result.text, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                }
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onASRResult(text: result.text, isFinal: result.isFinal)
                }
            }

        case SEEventASREnded:
            let providerMetadata = observeProviderQuestionEvent(
                data,
                stage: "asrEnded",
                callbackContext: callbackContext
            )
            DDLogInfo("[DialogEngine] ASR 结束")

        case SEEventChatTextQueryConfirmed:
            let providerMetadata = observeProviderQuestionEvent(
                data,
                stage: "queryConfirmed",
                callbackContext: callbackContext
            )
            let confirmedQueryText = parseQueryConfirmedText(from: data)
            interruptForNewProviderQuestionIfNeeded(
                metadata: providerMetadata,
                recognizedText: confirmedQueryText,
                callbackContext: callbackContext
            )
            guard selectDelegatedClientTTSRouteIfNeeded(force: true) else {
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onError(
                        error: DialogEngineError.sdkError(
                            code: Int(SEDirectiveDialogUseClientTriggerTts.rawValue),
                            message: "回响语音路由切换失败"
                        )
                    )
                }
                return
            }
            // 用户语音已确认，这是发送给 LLM 的最终文本
            PrivacySafeDiagnostics.log(
                subsystem: "DialogEngine",
                event: "liveQueryConfirmed",
                counts: ["payloadBytes": data.count]
            )
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            // 解析用户查询文本
            if let queryText = confirmedQueryText, !queryText.isEmpty {
                // 检测结束关键词
                if let keyword = checkEndKeyword(in: queryText) {
                    print("[DialogEngine] 🛑 用户确认文本中检测到结束关键词: \(keyword)")
                    isEnding = true
                    deliverProviderCallback(callbackContext) { manager, delegate in
                        delegate.onASRResult(text: queryText, isFinal: true)
                        manager.stopDialog(reason: .keyword(keyword))
                    }
                    return
                }
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onASRResult(text: queryText, isFinal: true)
                }
            }

        // MARK: TTS Events
        case SEEventTTSSentenceStart:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire TTS sentence start; Tencent owns audible playback")
                return
            }
            let (_, replyCorrelation) = observeProviderReplyEvent(
                data,
                stage: "ttsSentenceStart",
                callbackContext: callbackContext
            )
            guard acceptsProviderReply(replyCorrelation) else { return }
            guard acceptsDelegatedTTSEvent(data, phase: .started) else { return }
            if sessionLifetimePolicy == .userControlledLive,
               answerAuthority == .dreamJourneyBackend,
               let replyID = delegatedClientPlaybackReplyID {
                guard emitDelegatedPlaybackProgress(
                    .providerAccepted(replyID: replyID),
                    callbackContext: callbackContext
                ) else { return }
            }
            // Delegated Live waits for the first encoded audio packet before
            // considering playback interruptible. Other modes preserve the
            // provider-owned behavior.
            if sessionLifetimePolicy != .userControlledLive
                || answerAuthority != .dreamJourneyBackend {
                isAISpeaking = true
            }
            if pendingTextReplyPlayback != nil {
                return
            }
            // AI 说话时也重置静音计时器（AI 播报期间不应触发超时）
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            if let text = parseTTSText(from: data), !text.isEmpty {
                _ = updateCanonicalAssistantText(text)
                if !chatBuffer.isEmpty {
                    // streaming 已经展示了内容，不重复调用 onTTSStarted
                    chatBuffer = ""
                } else {
                    // 没有 streaming，TTS 是唯一的文本来源
                    deliverProviderCallback(callbackContext) { _, delegate in
                        delegate.onTTSStarted(text: text)
                    }
                }
            } else if !chatBuffer.isEmpty {
                // TTS 没文本但 streaming 已经展示了，清空 buffer 即可
                chatBuffer = ""
            }

        case SEEventTTSSentenceEnd:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire TTS sentence end; Tencent owns audible playback")
                return
            }
            let (_, replyCorrelation) = observeProviderReplyEvent(
                data,
                stage: "ttsSentenceEnd",
                callbackContext: callbackContext
            )
            guard acceptsProviderReply(replyCorrelation) else { return }
            guard acceptsDelegatedTTSEvent(data, phase: .sentenceEnded) else { return }
            if pendingTextReplyPlayback != nil {
                return
            }
            // 部分 SpeechEngine 版本在 SentenceStart 只给空文本，完整文本出现在
            // SentenceEnd。数字人主音频模式依赖这里的文本转交给腾讯云渲染。
            if let text = parseTTSText(from: data), !text.isEmpty {
                _ = updateCanonicalAssistantText(text)
                chatBuffer = ""
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onTTSStarted(text: text)
                }
            }

        case SEEventTTSEnded:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire TTS ended; Tencent owns audible playback")
                return
            }
            let (_, replyCorrelation) = observeProviderReplyEvent(
                data,
                stage: "ttsEnded",
                callbackContext: callbackContext
            )
            guard acceptsProviderReply(replyCorrelation) else { return }
            guard acceptsDelegatedTTSEvent(data, phase: .streamEnded) else { return }
            DDLogInfo("[DialogEngine] TTS 播放结束")
            if let playback = pendingTextReplyPlayback {
                isAISpeaking = false
                scheduleTextReplyPlaybackCompletionFallback(playbackID: playback.id)
                return
            }
            if sessionLifetimePolicy == .userControlledLive,
               answerAuthority == .dreamJourneyBackend {
                guard let replyID = delegatedClientPlaybackReplyID else { return }
                guard emitDelegatedPlaybackProgress(
                    .synthesisEnded(replyID: replyID),
                    callbackContext: callbackContext
                ) else { return }
                DDLogInfo("[DialogEngine] delegated Live synthesis ended; awaiting player terminal event")
                return
            }
            if isProviderOwnedLive {
                providerPCMDrain.synthesized(
                    replyID: providerTurnCorrelation.currentReplyID,
                    generation: callbackContext.engineGeneration
                )
            }
            let playbackOutcome = providerReplyPlaybackState.receive(
                .synthesisEnded,
                replyID: providerTurnCorrelation.currentReplyID,
                generation: callbackContext.engineGeneration
            )
            if playbackOutcome == .drained {
                isAISpeaking = false
                providerInterruptionState.clearAudibleReply()
                deliverProviderCallback(callbackContext) { manager, delegate in
                    manager.resetSilenceTimer()
                    delegate.onTTSFinished()
                }
            }

        case SEEventConfigUpdated:
            if liveContextUpdates.acknowledge(now: ProcessInfo.processInfo.systemUptime) {
                recordNativeLiveDiagnostic(event: "contextUpdateAcknowledged", reason: "currentOperation")
            }

        case SEEventTTSResponse:
            break

        case SEPlayerAudioData:
            if isProviderOwnedLive, config.enablePlayer,
               providerPCMDrain.played(data,
                   replyID: providerTurnCorrelation.currentReplyID,
                   generation: callbackContext.engineGeneration) {
                isAISpeaking = false
                providerInterruptionState.clearAudibleReply()
                recordNativeLiveDiagnostic(event: "playerPCMDrained", reason: "decodedPlayerSamplesVerified")
                deliverProviderCallback(callbackContext) { manager, delegate in
                    manager.resetSilenceTimer()
                    delegate.onTTSFinished()
                }
            }
            if sessionLifetimePolicy == .userControlledLive,
               answerAuthority == .dreamJourneyBackend,
               let replyID = delegatedClientPlaybackReplyID,
               !delegatedClientPlaybackAudioActivityObserved,
               delegatedClientPlaybackState.phase != .idle {
                if emitDelegatedPlaybackProgress(
                    .audioActivityObserved(replyID: replyID),
                    callbackContext: callbackContext
                ) {
                    delegatedClientPlaybackAudioActivityObserved = true
                }
            }
            break

        case SEDecoderAudioData:
            if isProviderOwnedLive, config.enablePlayer {
                providerPCMDrain.decoded(data,
                    replyID: providerTurnCorrelation.currentReplyID,
                    generation: callbackContext.engineGeneration)
            }
            break

        case SEPlayerStartPlayAudio:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire player start; Tencent owns audible playback")
                return
            }
            observeLiveFirstResponseIfNeeded(callbackContext: callbackContext)
            recordProviderFirstOutput(
                kind: "audio",
                replyID: providerTurnCorrelation.currentReplyID,
                callbackContext: callbackContext
            )
            if sessionLifetimePolicy == .userControlledLive,
               answerAuthority == .dreamJourneyBackend {
                guard let replyID = delegatedClientPlaybackReplyID,
                      emitDelegatedPlaybackProgress(
                        .audioStarted(replyID: replyID),
                        callbackContext: callbackContext
                      ) else { return }
                isAISpeaking = true
                return
            }
            isAISpeaking = true
            providerInterruptionState.beginAudibleReply(
                questionID: providerTurnCorrelation.currentQuestionID,
                generation: callbackContext.engineGeneration
            )
            DDLogInfo("[DialogEngine] 播放器开始播放")
            _ = providerReplyPlaybackState.receive(
                .playerStarted,
                replyID: providerTurnCorrelation.currentReplyID,
                generation: callbackContext.engineGeneration
            )
            deliverProviderCallback(callbackContext) { _, delegate in
                delegate.onTTSPlaybackStarted()
            }

        case SEPlayerFinishPlayAudio:
            if isProviderOwnedLive, providerPCMDrain.didDrain { return }
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire player finish; Tencent owns audible playback")
                return
            }
            if sessionLifetimePolicy == .userControlledLive,
               answerAuthority == .dreamJourneyBackend {
                guard let replyID = delegatedClientPlaybackReplyID,
                      emitDelegatedPlaybackProgress(
                        .audioFinished(replyID: replyID),
                        callbackContext: callbackContext
                      ) else { return }
                delegatedClientTTSReplyIDs.remove(replyID)
                resetDelegatedClientPlaybackState()
                isAISpeaking = false
                return
            }
            DDLogInfo("[DialogEngine] 播放器播放完毕")
            if completeTextReplyPlayback(.success(()), stopsProviderSession: true) {
                return
            }
            let playbackOutcome = providerReplyPlaybackState.receive(
                .playerFinished,
                replyID: providerTurnCorrelation.currentReplyID,
                generation: callbackContext.engineGeneration
            )
            if playbackOutcome == .drained {
                isAISpeaking = false
                providerInterruptionState.clearAudibleReply()
                deliverProviderCallback(callbackContext) { manager, delegate in
                    manager.resetSilenceTimer()
                    delegate.onTTSFinished()
                }
            }

        // MARK: Chat Events
        case SEEventChatResponse:
            guard answerAuthority != .dreamJourneyBackend else {
                // In delegated mode `/echo/answers` is the only answer authority.
                // Provider-side chat text must not overwrite the grounded answer.
                return
            }
            let (metadata, replyCorrelation) = observeProviderReplyEvent(
                data,
                stage: "chatResponse",
                callbackContext: callbackContext
            )
            guard acceptsProviderReply(replyCorrelation) else { return }
            if let replyID = metadata.replyID,
               providerActiveChatReplyID != replyID {
                providerActiveChatReplyID = replyID
                chatBuffer = ""
            }
            // AI 对话流式 chunk —— 拼接到 buffer，不直接展示
            if let text = parseChatText(from: data) {
                if !text.isEmpty {
                    recordProviderFirstOutput(
                        kind: "text",
                        replyID: metadata.replyID,
                        callbackContext: callbackContext
                    )
                }
                if let event = providerCanonicalAssistantStreamState.consume(
                    kind: .response,
                    data: data,
                    engineGeneration: callbackContext.engineGeneration,
                    capturedAt: Date()
                ) {
                    chatBuffer = event.text
                    providerCanonicalAssistantTextState.replace(
                        event.text,
                        replyID: providerTurnCorrelation.currentReplyID
                    )
                    deliverProviderCallback(callbackContext) { _, delegate in
                        delegate.onChatStreaming(text: event.text)
                    }
                }
            }

        case SEEventChatEnded:
            guard answerAuthority != .dreamJourneyBackend else {
                chatBuffer = ""
                return
            }
            let (metadata, replyCorrelation) = observeProviderReplyEvent(
                data,
                stage: "chatEnded",
                callbackContext: callbackContext
            )
            guard acceptsProviderReply(replyCorrelation) else { return }
            DDLogInfo("[DialogEngine] Chat 结束")
            // 如果 chatBuffer 有内容但未通过 TTS 展示，展示它
            if let event = providerCanonicalAssistantStreamState.consume(
                kind: .ended,
                data: data,
                engineGeneration: callbackContext.engineGeneration,
                capturedAt: Date()
            ) {
                let finalText = event.text
                providerCanonicalAssistantTextState.replace(
                    finalText,
                    replyID: providerTurnCorrelation.currentReplyID
                )
                chatBuffer = ""
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onTTSStarted(text: finalText)
                }
            }
            providerActiveChatReplyID = nil

        // MARK: Engine Events
        case SEEngineStart:
            print("[DialogEngine] ✅ 引擎已启动 (SEEngineStart)")
            DDLogInfo("[DialogEngine] 引擎启动成功")
            // 开场白由 SEEventSessionStarted → sendGreetingIfNeeded() 统一发送，此处不重复

        case SEEngineStop:
            print("[DialogEngine] 引擎已停止 (SEEngineStop)")

        case SEEngineError:
            let msg = parseErrorMessage(from: data)
            DDLogError(
                "[DialogEngine] engine error type=\(type.rawValue) "
                    + "payloadBytes=\(data.count) errorHash=\(PrivacySafeDiagnostics.correlationHash(msg))"
            )
            if sessionLifetimePolicy == .userControlledLive,
               answerAuthority == .dreamJourneyBackend,
               delegatedClientPlaybackState.phase != .idle,
               let replyID = delegatedClientPlaybackReplyID {
                _ = emitDelegatedPlaybackProgress(
                    .failed(replyID: replyID, code: msg),
                    callbackContext: callbackContext
                )
                isAISpeaking = false
                resetDelegatedClientPlaybackState()
                return
            }
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(type.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            deliverProviderCallback(callbackContext) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: Int(type.rawValue),
                        message: msg
                    )
                )
            }

        default:
            DDLogVerbose("[DialogEngine] 收到消息类型: \(type.rawValue)")
            // 兜底：未知事件中尝试提取 ASR 文本（部分 SDK 版本用不同事件类型发送 ASR 结果）
            if let extracted = extractAnyText(from: data), !extracted.isEmpty {
                // 只在包含中文字符时才认为是 ASR 结果（避免误抦引擎状态信息）
                let hasChinese = extracted.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
                if hasChinese {
                    PrivacySafeDiagnostics.log(
                        subsystem: "DialogEngine",
                        event: "liveFallbackASRObserved",
                        counts: ["textCharacters": extracted.count]
                    )
                    deliverProviderCallback(callbackContext) { manager, delegate in
                        manager.resetSilenceTimer()
                        delegate.onASRResult(text: extracted, isFinal: false)
                    }
                }
            }
        }
    }

    // MARK: - JSON Parsing Helpers

    private func submitPendingTextReplyPlayback() {
        guard let playback = pendingTextReplyPlayback,
              let engine else {
            return
        }

        let pauseResult = engine.send(SEDirectivePauseRecorder)
        guard pauseResult == SENoError else {
            completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(pauseResult.rawValue)
                    )
                ),
                stopsProviderSession: true
            )
            return
        }
        isRecorderPaused = true
        // startDialog(sendsGreeting: false) leaves this flag set because the
        // one-shot route bypasses sendGreetingIfNeeded(). Clear it so the next
        // real Live session keeps its normal greeting behavior.
        suppressGreetingForNextStart = false

        guard let payloadData = try? JSONSerialization.data(
            withJSONObject: ["content": playback.text],
            options: []
        ), let payload = String(data: payloadData, encoding: .utf8) else {
            completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.invalidText),
                stopsProviderSession: true
            )
            return
        }

        // SayHello is the same provider-side text-to-audio event already used
        // by the proven Live greeting path. It accepts arbitrary content and
        // keeps text Echo on the same realtime ticket, player, and role voice
        // without entering the microphone/LLM turn pipeline.
        let result = engine.send(SEDirectiveEventSayHello, data: payload)
        guard result == SENoError else {
            completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(result.rawValue)
                    )
                ),
                stopsProviderSession: true
            )
            return
        }
        playback.onStarted()
        print("[DialogEngine] text Echo reply submitted through realtime SayHello")
        DDLogInfo("[DialogEngine] text Echo reply submitted through realtime SayHello")
    }

    private func scheduleTextReplyPlaybackCompletionFallback(playbackID: UUID) {
        textReplyPlaybackFallbackWorkItem?.cancel()
        let characterCount = pendingTextReplyPlayback?.text.count ?? 0
        let delay = max(4.0, min(30.0, Double(characterCount) * 0.35))
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.pendingTextReplyPlayback?.id == playbackID else {
                return
            }
            self.completeTextReplyPlayback(.success(()), stopsProviderSession: true)
        }
        textReplyPlaybackFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @discardableResult
    private func completeTextReplyPlayback(
        _ result: Result<Void, Error>,
        stopsProviderSession: Bool
    ) -> Bool {
        guard let playback = pendingTextReplyPlayback else { return false }
        textReplyPlaybackFallbackWorkItem?.cancel()
        textReplyPlaybackFallbackWorkItem = nil
        pendingTextReplyPlayback = nil
        if stopsProviderSession {
            closeTextReplyProviderSession()
        }
        playback.completion(result)
        return true
    }

    private func closeTextReplyProviderSession() {
        invalidateSilenceTimer()
        if activeDialogOperationId != nil {
            _ = engine?.send(SEDirectiveSyncStopEngine)
        }
        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        isEnding = false
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        resetLiveContextUpdates()
        activeDialogOperationId = nil
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        restoreAudioSessionIfNeeded()
    }

    private func parseTTSText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = json["text"] as? String { return text }
        if let sentence = json["sentence"] as? String { return sentence }
        return nil
    }

    /// 解析 ChatTextQueryConfirmed 事件中的用户查询文本
    private func parseQueryConfirmedText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 非 JSON，直接尝试当作纯文本
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                // 去掉引号和空白
                let cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "\"")))
                return cleaned.isEmpty ? nil : cleaned
            }
            return nil
        }
        // 常见字段名
        if let text = json["text"] as? String, !text.isEmpty { return text }
        if let query = json["query"] as? String, !query.isEmpty { return query }
        if let content = json["content"] as? String, !content.isEmpty { return content }
        if let input = json["input"] as? String, !input.isEmpty { return input }
        if let result = json["result"] as? String, !result.isEmpty { return result }
        if let message = json["message"] as? String, !message.isEmpty { return message }
        // 尝试从嵌套结构中查找
        if let asr = json["asr"] as? [String: Any] {
            if let text = asr["text"] as? String, !text.isEmpty { return text }
            if let result = asr["result"] as? String, !result.isEmpty { return result }
        }
        return nil
    }

    private func parseChatText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = json["text"] as? String { return text }
        if let content = json["content"] as? String { return content }
        if let message = json["message"] as? String { return message }
        // Dialog SDK 可能用 delta 字段表示增量文本
        if let delta = json["delta"] as? String { return delta }
        return nil
    }

    /// 从 JSON 中提取任何可用的文本字段（兆底方案）
    private func extractAnyText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        // 遍历所有常见文本字段名
        let textKeys = ["text", "result", "content", "sentence", "message", "transcript", "asr_text"]
        for key in textKeys {
            if let text = json[key] as? String, !text.isEmpty {
                return text
            }
        }
        // 尝试从嵌套结构中查找
        for (_, value) in json {
            if let dict = value as? [String: Any] {
                for key in textKeys {
                    if let text = dict[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
            if let arr = value as? [[String: Any]], let first = arr.first {
                for key in textKeys {
                    if let text = first[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
        }
        return nil
    }

    private func parseErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "未知错误"
        }
        if let msg = json["message"] as? String { return msg }
        if let msg = json["error"] as? String { return msg }
        if let msg = json["msg"] as? String { return msg }
        if let error = json["err_msg"] as? [String: Any] {
            if let msg = error["message"] as? String { return msg }
            if let msg = error["error"] as? String { return msg }
            if let msg = error["msg"] as? String { return msg }
        }
        return "未知错误 (\(json))"
    }

    /// 从 raw string 中提取中文文本（最终兜底方案）
    private func extractChineseText(from rawStr: String) -> String {
        // 尝试匹配引号内的中文内容，如 "text":"..."
        let patterns = [
            "\"text\"\\s*:\\s*\"([^\"]+)\"",
            "\"result\"\\s*:\\s*\"([^\"]+)\"",
            "\"content\"\\s*:\\s*\"([^\"]+)\"",
            "\"sentence\"\\s*:\\s*\"([^\"]+)\"",
            "\"transcript\"\\s*:\\s*\"([^\"]+)\""
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: rawStr, range: NSRange(rawStr.startIndex..., in: rawStr)),
               let range = Range(match.range(at: 1), in: rawStr) {
                let text = String(rawStr[range])
                if !text.isEmpty { return text }
            }
        }
        return ""
    }

    // MARK: - 开场白

    /// 会话建立后发送中性开场白。正式记忆只在当前用户问题确定后由
    /// V4 Context 检索，不能用本地关键词摘要冒充已确认的跨会话记忆。
    private func sendGreetingIfNeeded() {
        guard let engine = engine else { return }
        guard !suppressGreetingForNextStart else {
            suppressGreetingForNextStart = false
            print("[DialogEngine] skipped greeting for resumed digital-human listening")
            DDLogInfo("[DialogEngine] 恢复数字人监听，跳过开场白")
            return
        }

        let greeting = recommendedTopicGreeting()

        let payload: [String: Any] = ["content": greeting]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: jsonData, encoding: .utf8) else { return }

        let result = engine.send(SEDirectiveEventSayHello, data: jsonStr)
        if result == SENoError {
            DDLogInfo("[DialogEngine] greeting submitted characters=\(greeting.count)")
        } else {
            DDLogError("[DialogEngine] greeting submission failed code=\(result.rawValue)")
        }
    }

    /// 不读取本地 ConversationMemory/KBLite，避免把未确认或残缺片段
    /// 表述成“上次记得的事实”。
    private func recommendedTopicGreeting() -> String {
        LiveSessionGreetingPolicy.makeGreeting()
    }

    // MARK: - 记忆上下文构建

    /// 将历史记忆构建为 system_prompt 追加段落（基于四维度摘要 + 知识库）
    private func buildMemoryContext(memory: ConversationMemory) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月d日"
        let dateStr = dateFormatter.string(from: memory.lastSessionDate)

        let summary = memory.lastSummary
        var context = "\n\n【用户记忆档案】\n"
        context += "- 这是第\(memory.sessionCount + 1)次和这位长辈聊天。\n"
        context += "- 上次聊天时间：\(dateStr)\n"

        if !summary.time.isEmpty {
            context += "- 提到的时间：\(summary.time)\n"
        }
        if !summary.place.isEmpty {
            context += "- 提到的地方：\(summary.place)\n"
        }
        if !summary.person.isEmpty {
            context += "- 提到的人物：\(summary.person)\n"
        }
        if !summary.event.isEmpty {
            context += "- 聊到的事件：\(summary.event)\n"
        }

        if summary.hasAnyDimension {
            let sentence = summary.toNaturalSentence()
            context += "- 上次对话摘要：\(sentence)\n"
        }

        // 【KBLite】附加知识库上下文（累计的人物、地点、事件、事实）
        let kbContext = KBLiteManager.shared.buildGenerationAllowedContextString(query: nil)
        if !kbContext.isEmpty {
            context += kbContext
        }

        // V4: legacy KBLite is a compatibility projection only. It must not
        // independently select follow-up questions or present inferred gaps as
        // an Echo instruction; authoritative recommendations come from the
        // Owner Truth recommendation flow after its policy checks.

        context += "\n请基于以上记忆自然地延续话题，让长辈感受到你记得他/她说过的事。\n"
        context += "不要直接报出以上信息，而是在对话中自然地引用。\n"
        context += "继续围绕时间、地点、人物、事件这四个维度追问细节，帮老人把故事讲完整。"

        return context
    }

    private func buildArchiveContext() -> String {
        let context = DigitalHumanContextStore.shared.current
        guard shouldExposeArchiveContext(for: context) else { return "" }
        return MemoryArchiveRepository.shared.contextSnapshot().promptSection
    }
}

// MARK: - Error

enum DialogEngineError: LocalizedError {
    case productionConfigurationMissing
    case initFailed(code: Int)
    case startFailed(code: Int)
    case audioSessionFailed
    case sdkError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .productionConfigurationMissing:
            return "实时语音凭据代理尚未开放，当前可继续使用文字回响"
        case .initFailed(let code):
            return "语音引擎初始化失败 (错误码: \(code))"
        case .startFailed(let code):
            return "语音对话启动失败 (错误码: \(code))"
        case .audioSessionFailed:
            return "音频配置失败，请重试"
        case .sdkError(_, let message):
            return "语音服务异常: \(message)"
        }
    }
}
#endif
