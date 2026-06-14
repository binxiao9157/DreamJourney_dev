import Foundation
import Speech

enum MemoryArchiveVoiceTranscriptionError: Error, LocalizedError {
    case recognizerUnavailable
    case notAuthorized
    case restricted
    case denied
    case emptyResult
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable:
            return "当前设备暂不可用语音识别"
        case .notAuthorized:
            return "语音识别尚未授权"
        case .restricted:
            return "系统限制了语音识别"
        case .denied:
            return "未允许语音识别权限"
        case .emptyResult:
            return "未识别到可用文字"
        case .failed(let message):
            return "语音识别失败：\(message)"
        }
    }
}

final class MemoryArchiveVoiceTranscriber {
    static let shared = MemoryArchiveVoiceTranscriber()

    private var activeTasks: [UUID: SFSpeechRecognitionTask] = [:]
    private let lock = NSLock()

    func transcribeAudio(
        at localPath: String,
        locale: Locale = Locale(identifier: "zh_CN"),
        completion: @escaping (Result<String, MemoryArchiveVoiceTranscriptionError>) -> Void
    ) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self else { return }
            switch status {
            case .authorized:
                self.startTranscription(localPath: localPath, locale: locale, completion: completion)
            case .notDetermined:
                completion(.failure(.notAuthorized))
            case .restricted:
                completion(.failure(.restricted))
            case .denied:
                completion(.failure(.denied))
            @unknown default:
                completion(.failure(.notAuthorized))
            }
        }
    }

    private func startTranscription(
        localPath: String,
        locale: Locale,
        completion: @escaping (Result<String, MemoryArchiveVoiceTranscriptionError>) -> Void
    ) {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            completion(.failure(.recognizerUnavailable))
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: localPath))
        request.shouldReportPartialResults = false
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }

        let taskID = UUID()
        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            if let result, result.isFinal {
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                self?.finishTask(taskID)
                if text.isEmpty {
                    completion(.failure(.emptyResult))
                } else {
                    completion(.success(text))
                }
                return
            }

            if let error {
                self?.finishTask(taskID)
                completion(.failure(.failed(error.localizedDescription)))
            }
        }
        lock.lock()
        activeTasks[taskID] = task
        lock.unlock()
    }

    private func finishTask(_ taskID: UUID) {
        lock.lock()
        activeTasks[taskID] = nil
        lock.unlock()
    }
}
