import AVFoundation
import UIKit

final class MemoryArchiveAudioRecorderViewController: UIViewController, UITextViewDelegate, AVAudioRecorderDelegate {
    var onSave: ((URL, TimeInterval, String) -> Void)?

    private let statusLabel = UILabel()
    private let durationLabel = UILabel()
    private let recordButton = UIButton(type: .system)
    private let noteTextView = UITextView()
    private let placeholderLabel = UILabel()
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private lazy var saveButton = DJComponentFactory.primaryButton(
        title: "保存语音档案",
        target: self,
        action: #selector(saveTapped)
    )

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var audioURL: URL?
    private var recordedDuration: TimeInterval = 0
    private var shouldKeepRecordedFile = false
    private var recordingAccountLease: AccountLease?

    private var hasRecording: Bool {
        audioURL != nil && recordedDuration > 0
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = DJDesignTokens.Color.background
        configureSheet()
        buildLayout()
        updateState(isRecording: false)
        updateSaveButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            finishRecordingIfNeeded()
            let canKeepFile = shouldKeepRecordedFile
                && recordingAccountLease.map {
                    validateRecordingAccountLease($0, at: .commit)
                } == true
            if !canKeepFile, let audioURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
            recordingAccountLease = nil
        }
    }

    private func configureSheet() {
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = DJDesignTokens.Radius.extraLarge
        }
    }

    private func buildLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "录入语音"
        titleLabel.font = DJDesignTokens.Font.display(32)
        titleLabel.textColor = DJDesignTokens.Color.textPrimary
        titleLabel.numberOfLines = 0

        let subtitleLabel = UILabel()
        subtitleLabel.text = "录下一段声音，或者补充一两句说明，之后回响会把它当作语气与情绪线索。"
        subtitleLabel.font = DJDesignTokens.Font.body(15)
        subtitleLabel.textColor = DJDesignTokens.Color.textSecondary
        subtitleLabel.numberOfLines = 0

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = DJDesignTokens.Font.label(14)
        cancelButton.setTitleColor(DJDesignTokens.Color.textSecondary, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, UIView(), cancelButton])
        headerStack.axis = .horizontal
        headerStack.alignment = .top
        headerStack.spacing = 12

        let recorderCard = UIView()
        recorderCard.backgroundColor = DJDesignTokens.Color.surface
        recorderCard.layer.cornerRadius = DJDesignTokens.Radius.extraLarge
        recorderCard.layer.borderWidth = 1
        recorderCard.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor
        DJDesignTokens.applySoftShadow(to: recorderCard)

        let iconContainer = UIView()
        iconContainer.backgroundColor = DJDesignTokens.Color.surfaceContainer.withAlphaComponent(0.72)
        iconContainer.layer.cornerRadius = 28

        let iconView = UIImageView(image: UIImage(systemName: "waveform"))
        iconView.tintColor = DJDesignTokens.Color.accentDeep
        iconView.contentMode = .scaleAspectFit

        statusLabel.font = DJDesignTokens.Font.title(17)
        statusLabel.textColor = DJDesignTokens.Color.textPrimary
        statusLabel.textAlignment = .center

        durationLabel.font = DJDesignTokens.Font.display(36)
        durationLabel.textColor = DJDesignTokens.Color.accentDeep
        durationLabel.textAlignment = .center
        durationLabel.text = "00:00"

        recordButton.titleLabel?.font = DJDesignTokens.Font.label(16)
        recordButton.layer.cornerRadius = 28
        recordButton.addTarget(self, action: #selector(recordTapped), for: .touchUpInside)

        let recorderStack = UIStackView(arrangedSubviews: [iconContainer, statusLabel, durationLabel, recordButton])
        recorderStack.axis = .vertical
        recorderStack.alignment = .center
        recorderStack.spacing = 14

        let noteCard = UIView()
        noteCard.backgroundColor = DJDesignTokens.Color.surface
        noteCard.layer.cornerRadius = DJDesignTokens.Radius.large
        noteCard.layer.borderWidth = 1
        noteCard.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.50).cgColor

        noteTextView.delegate = self
        noteTextView.backgroundColor = .clear
        noteTextView.font = DJDesignTokens.Font.body(16)
        noteTextView.textColor = DJDesignTokens.Color.textPrimary
        noteTextView.tintColor = DJDesignTokens.Color.accentDeep
        noteTextView.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        noteTextView.textContainer.lineFragmentPadding = 0

        placeholderLabel.text = "这段声音想记录什么？"
        placeholderLabel.font = DJDesignTokens.Font.body(16)
        placeholderLabel.textColor = DJDesignTokens.Color.textTertiary.withAlphaComponent(0.56)

        let helperLabel = UILabel()
        helperLabel.text = "仅保存你主动录入的声音和说明，不展示聊天原文。"
        helperLabel.font = DJDesignTokens.Font.label(12)
        helperLabel.textColor = DJDesignTokens.Color.textTertiary
        helperLabel.numberOfLines = 0

        saveButton.titleLabel?.font = DJDesignTokens.Font.label(16)
        saveButton.setTitleColor(DJDesignTokens.Color.accentDeep, for: .normal)
        saveButton.layer.cornerRadius = 28

        let contentStack = UIStackView(arrangedSubviews: [
            headerStack,
            subtitleLabel,
            recorderCard,
            noteCard,
            helperLabel,
            saveButton,
        ])
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.isLayoutMarginsRelativeArrangement = true
        contentStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 30,
            leading: DJDesignTokens.Spacing.page,
            bottom: 28,
            trailing: DJDesignTokens.Spacing.page
        )

        view.addSubview(contentStack)
        recorderCard.addSubview(recorderStack)
        iconContainer.addSubview(iconView)
        noteCard.addSubview(noteTextView)
        noteTextView.addSubview(placeholderLabel)

        [
            contentStack,
            headerStack,
            titleLabel,
            cancelButton,
            recorderCard,
            recorderStack,
            iconContainer,
            iconView,
            statusLabel,
            durationLabel,
            recordButton,
            noteCard,
            noteTextView,
            placeholderLabel,
            saveButton,
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: view.keyboardLayoutGuide.topAnchor, constant: -12),

            recorderStack.topAnchor.constraint(equalTo: recorderCard.topAnchor, constant: 22),
            recorderStack.leadingAnchor.constraint(greaterThanOrEqualTo: recorderCard.leadingAnchor, constant: 18),
            recorderStack.trailingAnchor.constraint(lessThanOrEqualTo: recorderCard.trailingAnchor, constant: -18),
            recorderStack.centerXAnchor.constraint(equalTo: recorderCard.centerXAnchor),
            recorderStack.bottomAnchor.constraint(equalTo: recorderCard.bottomAnchor, constant: -22),

            iconContainer.widthAnchor.constraint(equalToConstant: 56),
            iconContainer.heightAnchor.constraint(equalToConstant: 56),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            recordButton.widthAnchor.constraint(equalToConstant: 164),
            recordButton.heightAnchor.constraint(equalToConstant: 56),

            noteCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 116),

            noteTextView.topAnchor.constraint(equalTo: noteCard.topAnchor),
            noteTextView.leadingAnchor.constraint(equalTo: noteCard.leadingAnchor),
            noteTextView.trailingAnchor.constraint(equalTo: noteCard.trailingAnchor),
            noteTextView.bottomAnchor.constraint(equalTo: noteCard.bottomAnchor),

            placeholderLabel.topAnchor.constraint(equalTo: noteTextView.topAnchor, constant: 16),
            placeholderLabel.leadingAnchor.constraint(equalTo: noteTextView.leadingAnchor, constant: 14),

            saveButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        timer?.invalidate()
        timer = nil
        guard let accountLease = recordingAccountLease,
              validateRecordingAccountLease(accountLease, at: .runtime),
              validateRecordingAccountLease(accountLease, at: .commit) else {
            discardStaleRecording()
            return
        }
        recordedDuration = max(recordedDuration, recorder.currentTime)
        updateState(isRecording: false)
        updateSaveButton()
        if !flag {
            statusLabel.text = "录音未保存，请重新录制"
            if let audioURL {
                try? FileManager.default.removeItem(at: audioURL)
            }
            audioURL = nil
            recordedDuration = 0
            recordingAccountLease = nil
            updateSaveButton()
        }
    }

    @objc private func recordTapped() {
        if recorder?.isRecording == true {
            guard let accountLease = recordingAccountLease,
                  validateRecordingAccountLease(accountLease, at: .runtime) else {
                discardStaleRecording()
                return
            }
            finishRecordingIfNeeded()
            updateSaveButton()
            return
        }

        guard let accountLease = captureRecordingAccountLease() else {
            statusLabel.text = "账号状态已变化，请重新进入后再录音"
            updateSaveButton()
            return
        }
        recordingAccountLease = accountLease
        MicrophonePermissionManager.shared.requestPermission { [weak self] granted in
            guard let self,
                  self.recordingAccountLease == accountLease,
                  self.validateRecordingAccountLease(accountLease, at: .runtime),
                  self.validateRecordingAccountLease(accountLease, at: .ui) else {
                self?.discardStaleRecording()
                return
            }
            guard granted else {
                self.handleMicrophonePermissionDenied()
                return
            }
            self.startRecording(accountLease: accountLease)
        }
    }

    @objc private func cancelTapped() {
        shouldKeepRecordedFile = false
        discardStaleRecording()
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        finishRecordingIfNeeded()
        guard let accountLease = recordingAccountLease,
              validateRecordingAccountLease(accountLease, at: .commit),
              let audioURL,
              recordedDuration > 0 else {
            discardStaleRecording()
            updateSaveButton()
            return
        }

        shouldKeepRecordedFile = true
        let note = noteTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let onSave = onSave
        let duration = recordedDuration
        dismiss(animated: true) { [weak self] in
            guard let self,
                  self.validateRecordingAccountLease(accountLease, at: .ui) else {
                try? FileManager.default.removeItem(at: audioURL)
                return
            }
            onSave?(audioURL, duration, note)
        }
    }

    private func startRecording(accountLease: AccountLease) {
        do {
            guard recordingAccountLease == accountLease,
                  validateRecordingAccountLease(accountLease, at: .runtime) else {
                discardStaleRecording()
                return
            }
            let fileURL = try makeAudioFileURL(accountLease: accountLease)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            guard validateRecordingAccountLease(accountLease, at: .runtime) else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                try? FileManager.default.removeItem(at: fileURL)
                discardStaleRecording()
                return
            }

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]

            finishRecordingIfNeeded()
            if let audioURL, audioURL != fileURL {
                try? FileManager.default.removeItem(at: audioURL)
            }

            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.record()

            self.recorder = recorder
            self.audioURL = fileURL
            self.recordingAccountLease = accountLease
            recordedDuration = 0
            updateState(isRecording: true)
            updateSaveButton()
            startTimer(accountLease: accountLease)
        } catch {
            discardStaleRecording()
            if validateRecordingAccountLease(accountLease, at: .ui) {
                statusLabel.text = "录音启动失败，请稍后重试"
                updateState(isRecording: false)
                updateSaveButton()
            }
        }
    }

    private func finishRecordingIfNeeded() {
        guard let recorder else { return }
        if recorder.isRecording {
            recordedDuration = max(1, recorder.currentTime)
            recorder.stop()
        }
        self.recorder = nil
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        updateState(isRecording: false)
    }

    private func startTimer(accountLease: AccountLease) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.recordingAccountLease == accountLease,
                  self.validateRecordingAccountLease(accountLease, at: .timer),
                  let recorder = self.recorder else {
                self.discardStaleRecording()
                return
            }
            self.recordedDuration = recorder.currentTime
            self.durationLabel.text = self.formatDuration(self.recordedDuration)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func updateState(isRecording: Bool) {
        statusLabel.text = isRecording
            ? "正在录音"
            : (hasRecording ? "录音已准备好" : "准备录入语音")
        recordButton.setTitle(isRecording ? "停止录音" : (hasRecording ? "重新录音" : "开始录音"), for: .normal)
        recordButton.backgroundColor = isRecording
            ? DJDesignTokens.Color.danger.withAlphaComponent(0.12)
            : DJDesignTokens.Color.accent
        recordButton.setTitleColor(
            isRecording ? DJDesignTokens.Color.danger : DJDesignTokens.Color.accentDeep,
            for: .normal
        )
        durationLabel.text = formatDuration(recordedDuration)
    }

    private func updateSaveButton() {
        saveButton.isEnabled = hasRecording
        saveButton.alpha = hasRecording ? 1 : 0.55
    }

    private func handleMicrophonePermissionDenied(shouldPresentAlert: Bool = true) {
        finishRecordingIfNeeded()
        recordingAccountLease = nil
        updateState(isRecording: false)
        statusLabel.text = "录音需要麦克风权限，可在系统设置开启后再试"
        updateSaveButton()
        if shouldPresentAlert {
            MicrophonePermissionManager.shared.showPermissionDeniedAlert(on: self)
        }
    }

    #if DEBUG || UI_QA_SIMULATOR
    func runUIQAPermissionDeniedRecoverySmoke() -> Bool {
        handleMicrophonePermissionDenied(shouldPresentAlert: false)
        return recorder == nil
            && audioURL == nil
            && recordedDuration == 0
            && !saveButton.isEnabled
            && statusLabel.text == "录音需要麦克风权限，可在系统设置开启后再试"
    }
    #endif

    private func captureRecordingAccountLease() -> AccountLease? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              validateRecordingAccountLease(accountLease, at: .request) else {
            return nil
        }
        return accountLease
    }

    private func validateRecordingAccountLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        accountLease.subjectId == UserManager.shared.currentUser?.id
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    private func discardStaleRecording() {
        recorder?.delegate = nil
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        recorder = nil
        timer?.invalidate()
        timer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if let audioURL {
            try? FileManager.default.removeItem(at: audioURL)
        }
        audioURL = nil
        recordedDuration = 0
        shouldKeepRecordedFile = false
        recordingAccountLease = nil
    }

    private func makeAudioFileURL(accountLease: AccountLease) throws -> URL {
        guard validateRecordingAccountLease(accountLease, at: .commit) else {
            throw AudioRecordingCommitError.accountSessionChanged
        }
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = documentsURL.appendingPathComponent("archive-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard validateRecordingAccountLease(accountLease, at: .commit) else {
            throw AudioRecordingCommitError.accountSessionChanged
        }
        return directoryURL.appendingPathComponent("\(UUID().uuidString).m4a")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private enum AudioRecordingCommitError: Error {
    case accountSessionChanged
}
