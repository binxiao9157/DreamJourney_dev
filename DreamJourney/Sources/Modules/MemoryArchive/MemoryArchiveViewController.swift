import UIKit
import UniformTypeIdentifiers
import Vision

final class MemoryArchiveViewController: UIViewController {
    private enum PendingImageMaterialKind {
        case photo
        case screenshot

        var storageDirectoryName: String {
            switch self {
            case .photo: return "archive_photos"
            case .screenshot: return "archive_screenshots"
            }
        }

        var filePrefix: String {
            switch self {
            case .photo: return "archive_photo"
            case .screenshot: return "archive_screenshot"
            }
        }

        var saveFailureMessage: String {
            switch self {
            case .photo: return "照片保存失败"
            case .screenshot: return "截图保存失败"
            }
        }
    }

    private let repository: MemoryArchiveRepository
    private var items: [MemoryArchiveItem] = []
    private var backendArchiveItemCount: Int?
    private var backendArchiveLastCheckedAt: Date?
    private var backendSyncStatusOverride: String?
    private var knowledgeDepositStatusOverride: String?
    private var pendingImageMaterialKind: PendingImageMaterialKind = .photo

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "记忆档案馆"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .warmPrimary
        return label
    }()

    private let boundaryLabel: UILabel = {
        let label = UILabel()
        label.text = "这里保存的是照片、口头禅和性格线索，用来整理记忆，不代表逝者复活。"
        label.font = .systemFont(ofSize: 13)
        label.textColor = .warmSubtitle
        label.numberOfLines = 0
        return label
    }()

    private let summaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .warmPrimary
        label.numberOfLines = 0
        return label
    }()

    private let knowledgeDepositStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .warmSubtitle
        label.numberOfLines = 0
        return label
    }()

    private let backendSyncStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .warmSubtitle
        label.numberOfLines = 0
        return label
    }()

    private lazy var photoButton = makeActionButton(title: "上传旧照片", iconName: "photo.on.rectangle")
    private lazy var screenshotButton = makeActionButton(title: "导入截图/聊天记录", iconName: "text.viewfinder")
    private lazy var voiceButton = makeActionButton(title: "导入语音素材", iconName: "waveform")
    private lazy var textButton = makeActionButton(title: "添加文字/人格提示", iconName: "square.and.pencil")
    private lazy var knowledgeButton = makeActionButton(title: "结构化知识库", iconName: "brain.head.profile")

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.dataSource = self
        table.delegate = self
        table.register(MemoryArchiveCell.self, forCellReuseIdentifier: MemoryArchiveCell.reuseIdentifier)
        table.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        return table
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "还没有档案素材"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .warmSubtitle
        label.textAlignment = .center
        return label
    }()

    init(repository: MemoryArchiveRepository = .shared) {
        self.repository = repository
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        navigationController?.navigationBar.isHidden = true
        additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: WarmTabBarView.tabBarHeight, right: 0)
        setupActions()
        setupLayout()
        reloadData()
        refreshArchiveBackendSyncStatus()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = true
        reloadData()
        refreshArchiveBackendSyncStatus()
    }

    private func setupActions() {
        photoButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        screenshotButton.addTarget(self, action: #selector(screenshotTapped), for: .touchUpInside)
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        textButton.addTarget(self, action: #selector(textTapped), for: .touchUpInside)
        knowledgeButton.addTarget(self, action: #selector(knowledgeTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        let actionStack = UIStackView(arrangedSubviews: [photoButton, screenshotButton, voiceButton, textButton, knowledgeButton])
        actionStack.axis = .vertical
        actionStack.spacing = 10

        [titleLabel, boundaryLabel, summaryLabel, knowledgeDepositStatusLabel, backendSyncStatusLabel, actionStack, tableView, emptyLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            boundaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            boundaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            boundaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            summaryLabel.topAnchor.constraint(equalTo: boundaryLabel.bottomAnchor, constant: 12),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            knowledgeDepositStatusLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 6),
            knowledgeDepositStatusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            knowledgeDepositStatusLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            backendSyncStatusLabel.topAnchor.constraint(equalTo: knowledgeDepositStatusLabel.bottomAnchor, constant: 4),
            backendSyncStatusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            backendSyncStatusLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            actionStack.topAnchor.constraint(equalTo: backendSyncStatusLabel.bottomAnchor, constant: 14),
            actionStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor, constant: -20),
        ])
    }

    private func reloadData() {
        items = repository.items()
        let summary = repository.summary()
        summaryLabel.text = "共 \(summary.totalCount) 份素材 · 照片 \(summary.photoCount) · 截图 \(summary.screenshotCount) · 语音 \(summary.voiceSampleCount) · 文字 \(summary.textCount) · 已分析 \(summary.analyzedPhotoCount)"
        updateKnowledgeDepositStatusLabel()
        updateBackendSyncStatusLabel()
        emptyLabel.isHidden = !items.isEmpty
        tableView.reloadData()
    }

    @objc private func photoTapped() {
        pendingImageMaterialKind = .photo
        presentImagePicker()
    }

    @objc private func screenshotTapped() {
        pendingImageMaterialKind = .screenshot
        presentImagePicker()
    }

    private func presentImagePicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            showToast("当前设备无法访问相册", type: .error)
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func voiceTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func textTapped() {
        let composer = MemoryArchiveTextComposerViewController()
        composer.onSave = { [weak self] draft in
            self?.saveTextDraft(draft)
        }
        let nav = UINavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func knowledgeTapped() {
        let knowledgeVC = KnowledgeBaseViewController()
        knowledgeVC.title = "结构化知识库"
        navigationController?.navigationBar.isHidden = false
        navigationController?.pushViewController(knowledgeVC, animated: true)
    }

    private func saveTextDraft(_ draft: MemoryArchiveTextDraft) {
        let assessment = SafetyMonitor.shared.evaluate("\(draft.title)\n\(draft.note)")
        guard assessment.level != .high else {
            dismiss(animated: true) { [weak self] in
                let crisis = CrisisInterventionViewController(assessment: assessment)
                crisis.modalPresentationStyle = .fullScreen
                self?.present(crisis, animated: true)
            }
            return
        }

        do {
            let item = try repository.addText(
                kind: draft.kind,
                title: draft.title,
                note: draft.note,
                tags: draft.tags,
                isPrivate: draft.isPrivate,
                privacyMetadata: draft.privacyMetadata
            )
            if item.privacyMetadata.scope != .privateOnly {
                Stage1MemoryFacade.shared.ingestArchiveTextMaterialDetailed(Stage1MailboxMemoryInput(
                    item.note,
                    timestamp: item.createdAt,
                    privacyMetadata: item.privacyMetadata
                ), archiveItemID: item.id, archiveTitle: item.title, archiveMaterialKind: item.kind.displayName) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.setKnowledgeDepositStatus(self.archiveTextDepositStatusMessage(result))
                        if result.totalAddedCount > 0 {
                            self.showToast("知识库已更新 \(result.totalAddedCount) 条", type: .success)
                        }
                    }
                }
            } else {
                setKnowledgeDepositStatus("结构化建库：私密素材仅存档案馆，不进入知识库")
            }
            syncArchiveItemMetadataToBackend(item)
            dismiss(animated: true) { [weak self] in
                self?.showToast(
                    item.privacyMetadata.scope == .privateOnly ? "素材已保存" : "素材已保存，正在整理知识库",
                    type: .success
                )
                self?.reloadData()
            }
        } catch {
            showToast("请填写素材内容", type: .info)
        }
    }

    private func archiveTextDepositStatusMessage(_ result: Stage1ArchiveTextDepositResult) -> String {
        let total = result.totalAddedCount
        let extraction = result.extractionSummary
        guard total > 0 else {
            return "结构化建库：文字素材已保存，暂无可抽取的新知识"
        }
        if extraction.didFailLLM {
            return "结构化建库：已本地整理 \(total) 条，远端 AI 抽取暂未完成"
        }
        if extraction.llmAddedCount > 0 {
            return "结构化建库：文字素材已沉淀 \(total) 条，其中 AI 抽取 \(extraction.llmAddedCount) 条"
        }
        if extraction.didAttemptLLM {
            return "结构化建库：已本地整理 \(total) 条，AI 暂无新增线索"
        }
        if extraction.didSkipDueToFrequency {
            return "结构化建库：已本地整理 \(total) 条，AI 抽取按节奏稍后触发"
        }
        if extraction.didSkipDueToNoRemoteContent {
            return "结构化建库：已本地整理 \(total) 条，未进入远端抽取"
        }
        if result.metadataAddedCount > 0 && extraction.deterministicAddedCount == 0 {
            return "结构化建库：已保存档案元信息 \(result.metadataAddedCount) 条"
        }
        return "结构化建库：已本地整理 \(total) 条"
    }

    private func saveArchiveImage(_ image: UIImage, kind: PendingImageMaterialKind) -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let archiveDir = docs?.appendingPathComponent(kind.storageDirectoryName) else { return nil }
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        let fileName = "\(kind.filePrefix)_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).jpg"
        let fileURL = archiveDir.appendingPathComponent(fileName)
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }

    private func saveArchiveVoiceSample(from sourceURL: URL) -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let archiveDir = docs?.appendingPathComponent("archive_voice_samples") else { return nil }
        try? FileManager.default.createDirectory(at: archiveDir, withIntermediateDirectories: true)

        let hasSecurityAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let pathExtension = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let fileName = "archive_voice_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8)).\(pathExtension)"
        let fileURL = archiveDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: fileURL)
            return fileURL.path
        } catch {
            return nil
        }
    }

    private func analyzePhoto(_ image: UIImage, itemId: String) {
        let maxDimension: CGFloat = 1024
        let scaledImage: UIImage
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            scaledImage = image
        }

        guard let imageData = scaledImage.jpegData(compressionQuality: 0.6) else { return }
        let base64 = imageData.base64EncodedString()

        analyzePhotoViaBackendOrDirect(imageBase64: base64) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let kbAnalysis):
                    let archiveAnalysis = MemoryArchiveImageAnalysis(
                        summary: kbAnalysis.description,
                        detectedPeople: kbAnalysis.detectedPeople,
                        scene: kbAnalysis.scene.nilIfEmpty,
                        occasion: kbAnalysis.occasion.nilIfEmpty,
                        mood: kbAnalysis.mood.nilIfEmpty,
                        estimatedDecade: kbAnalysis.estimatedDecade
                    )
                    do {
                        let item = try self.repository.applyImageAnalysis(id: itemId, analysis: archiveAnalysis)
                        if item.privacyMetadata.scope != .privateOnly {
                            let beforeStatus = KBLiteDepositStatusBuilder.build(from: KBLiteManager.shared.graph)
                            let sessionId = ConversationMemoryManager.shared.currentMemory.sessionCount + 1
                            Stage1MemoryFacade.shared.ingestImageAnalysis(
                                kbAnalysis,
                                sessionId: sessionId,
                                privacyMetadata: item.privacyMetadata,
                                archiveItemID: item.id,
                                archiveTitle: item.title,
                                capturedAt: item.createdAt
                            )
                            let afterStatus = KBLiteDepositStatusBuilder.build(from: KBLiteManager.shared.graph)
                            let addedCount = max(0, afterStatus.totalEntityCount - beforeStatus.totalEntityCount)
                            if addedCount == 0 {
                                self.setKnowledgeDepositStatus("结构化建库：照片分析已完成，暂无可抽取的新知识")
                            } else {
                                self.setKnowledgeDepositStatus("结构化建库：照片分析已沉淀到知识库 \(addedCount) 条")
                            }
                        }
                        self.showToast("照片分析完成", type: .success)
                    } catch {
                        self.showToast("照片分析结果保存失败", type: .error)
                    }
                case .failure:
                    _ = try? self.repository.markAnalysisFailed(id: itemId)
                    self.setKnowledgeDepositStatus("结构化建库：照片分析失败，素材已保存；请检查 DeepSeek 或后端配置后重试")
                    self.showToast("照片已保存，分析稍后可重试", type: .info)
                }
                self.reloadData()
            }
        }
    }

    private func analyzePhotoViaBackendOrDirect(
        imageBase64: String,
        completion: @escaping (Result<KBImageAnalysisResult, Error>) -> Void
    ) {
        guard DreamJourneyBackendClient.shared.isConfigured else {
            analyzePhotoDirectly(imageBase64: imageBase64, completion: completion)
            return
        }

        DreamJourneyBackendClient.shared.analyzeArchiveImage(imageBase64: imageBase64) { result in
            switch result {
            case .success:
                completion(result)
            case .failure(let error):
                print("[MemoryArchive] 后端照片分析失败，回落本机 DeepSeekService: \(error.localizedDescription)")
                self.analyzePhotoDirectly(imageBase64: imageBase64, completion: completion)
            }
        }
    }

    private func analyzePhotoDirectly(
        imageBase64: String,
        completion: @escaping (Result<KBImageAnalysisResult, Error>) -> Void
    ) {
        DeepSeekService.shared.analyzeImage(imageBase64: imageBase64) { result in
            switch result {
            case .success(let analysis):
                completion(.success(analysis))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func makeActionButton(title: String, iconName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .warmSurface
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.warmDivider.cgColor
        button.tintColor = .warmAccent
        button.contentHorizontalAlignment = .leading
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: iconName)
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: UIColor.warmPrimary,
            ])
        )
        button.configuration = config
        return button
    }
}

extension MemoryArchiveViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let imageMaterialKind = pendingImageMaterialKind
        guard let image = info[.originalImage] as? UIImage,
              let imagePath = saveArchiveImage(image, kind: imageMaterialKind) else {
            picker.dismiss(animated: true)
            showToast(imageMaterialKind.saveFailureMessage, type: .error)
            return
        }

        picker.dismiss(animated: true) { [weak self] in
            self?.presentImagePrivacyChoice(image: image, imagePath: imagePath, kind: imageMaterialKind)
        }
    }

    private func presentImagePrivacyChoice(image: UIImage, imagePath: String, kind: PendingImageMaterialKind) {
        let title: String
        let message: String
        switch kind {
        case .photo:
            title = "照片保存方式"
            message = "私密只留在档案馆；可生成会调用图片分析；亲友可进入家庭同步。"
        case .screenshot:
            title = "截图保存方式"
            message = "适合微信聊天、语音记录或老照片说明截图；可生成会尝试做图片理解并沉淀线索。"
        }
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "私密", style: .default) { [weak self] _ in
            self?.savePickedImageMaterial(
                image,
                imagePath: imagePath,
                kind: kind,
                privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
            )
        })
        alert.addAction(UIAlertAction(title: "本机", style: .default) { [weak self] _ in
            self?.savePickedImageMaterial(
                image,
                imagePath: imagePath,
                kind: kind,
                privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)
            )
        })
        alert.addAction(UIAlertAction(title: "可生成", style: .default) { [weak self] _ in
            self?.savePickedImageMaterial(
                image,
                imagePath: imagePath,
                kind: kind,
                privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
            )
        })
        alert.addAction(UIAlertAction(title: "亲友", style: .default) { [weak self] _ in
            self?.presentImageFamilyVisibilityChoice(image: image, imagePath: imagePath, kind: kind)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )
        present(alert, animated: true)
    }

    private func presentImageFamilyVisibilityChoice(image: UIImage, imagePath: String, kind: PendingImageMaterialKind) {
        let picker = FamilyVisibilityPickerViewController()
        picker.onSelect = { [weak self] selection in
            self?.savePickedImageMaterial(
                image,
                imagePath: imagePath,
                kind: kind,
                privacyMetadata: MemoryPrivacyMetadata(
                    scope: MemoryPrivacyMigration.scopeForExplicitFamilyAuthorization(),
                    familyVisibility: selection.visibility
                )
            )
        }

        let navigationController = UINavigationController(rootViewController: picker)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func savePickedImageMaterial(
        _ image: UIImage,
        imagePath: String,
        kind: PendingImageMaterialKind,
        privacyMetadata: MemoryPrivacyMetadata
    ) {
        do {
            let item: MemoryArchiveItem
            switch kind {
            case .photo:
                item = try repository.addPhoto(
                    localPath: imagePath,
                    title: "旧照片",
                    note: "从相册加入的记忆照片",
                    tags: ["旧照片"],
                    isPrivate: privacyMetadata.scope == .privateOnly,
                    privacyMetadata: privacyMetadata
                )
            case .screenshot:
                item = try repository.addScreenshot(
                    localPath: imagePath,
                    title: "聊天截图",
                    note: "从相册加入的聊天记录或语音截图素材",
                    tags: ["截图素材", "聊天记录"],
                    isPrivate: privacyMetadata.scope == .privateOnly,
                    privacyMetadata: privacyMetadata
                )
            }
            reloadData()
            syncArchiveItemMetadataToBackend(item)
            extractScreenshotTextForKnowledge(from: image, item: item)
            if item.analysisStatus == .pending {
                setKnowledgeDepositStatus("结构化建库：\(item.kind.displayName)已保存，等待分析后建库")
                showToast("\(item.kind.displayName)已加入档案馆，开始分析", type: .success)
                analyzePhoto(image, itemId: item.id)
            } else {
                switch item.privacyMetadata.scope {
                case .privateOnly:
                    setKnowledgeDepositStatus("结构化建库：私密素材仅存档案馆，不进入知识库")
                case .familyCircle:
                    setKnowledgeDepositStatus("结构化建库：亲友\(item.kind.displayName)仅同步元数据，暂不做远端图片建库")
                case .localOnly:
                    setKnowledgeDepositStatus("结构化建库：本机\(item.kind.displayName)已存档，未进入生成知识库")
                case .generationAllowed:
                    setKnowledgeDepositStatus("结构化建库：\(item.kind.displayName)已存档，等待后续分析")
                }
                showToast("\(item.kind.displayName)已保存", type: .success)
            }
        } catch {
            showToast("素材加入失败", type: .error)
        }
    }

    private func extractScreenshotTextForKnowledge(from image: UIImage, item: MemoryArchiveItem) {
        guard item.kind == .screenshot else { return }
        guard item.privacyMetadata.scope != .privateOnly else { return }
        guard let cgImage = image.cgImage else {
            setKnowledgeDepositStatus("结构化建库：截图已保存，暂未识别到文字")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                if let error {
                    DispatchQueue.main.async {
                        self?.setKnowledgeDepositStatus("结构化建库：截图文字识别失败（\(error.localizedDescription)）")
                    }
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !recognizedText.isEmpty else {
                    DispatchQueue.main.async {
                        self?.setKnowledgeDepositStatus("结构化建库：截图已保存，未识别到可沉淀文字")
                    }
                    return
                }

                Stage1MemoryFacade.shared.ingestArchiveTextMaterialDetailed(
                    Stage1MailboxMemoryInput(
                        recognizedText,
                        timestamp: item.createdAt,
                        privacyMetadata: item.privacyMetadata
                    ),
                    archiveItemID: item.id,
                    archiveTitle: item.title,
                    archiveMaterialKind: "截图文字"
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.setKnowledgeDepositStatus(self.archiveTextDepositStatusMessage(result))
                        if result.totalAddedCount > 0 {
                            self.showToast("截图文字已整理到知识库 \(result.totalAddedCount) 条", type: .success)
                        }
                        self.reloadData()
                    }
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self?.setKnowledgeDepositStatus("结构化建库：截图文字识别失败（\(error.localizedDescription)）")
                }
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension MemoryArchiveViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first,
              let storedPath = saveArchiveVoiceSample(from: sourceURL) else {
            showToast("语音素材导入失败", type: .error)
            return
        }

        presentVoicePersonChoice(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            storedPath: storedPath
        )
    }

    private func presentVoicePersonChoice(title: String, storedPath: String) {
        let alert = UIAlertController(
            title: "这是谁的声音",
            message: "填写具体姓名后，3 段以上语音会形成这个人的声纹档案。请不要只写“妈妈/奶奶”这类泛称。",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "例如：林桂芳"
            field.text = MemoryArchiveVoiceProfileStore.shared.profile(for: title)?.personName
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "跳过", style: .default) { [weak self] _ in
            self?.presentVoicePrivacyChoice(title: title, storedPath: storedPath, targetPersonName: nil)
        })
        alert.addAction(UIAlertAction(title: "下一步", style: .default) { [weak self, weak alert] _ in
            let personName = alert?.textFields?.first?.text?.nilIfEmpty
            self?.presentVoicePrivacyChoice(title: title, storedPath: storedPath, targetPersonName: personName)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func presentVoicePrivacyChoice(
        title: String,
        storedPath: String,
        targetPersonName: String?
    ) {
        let alert = UIAlertController(
            title: "语音素材保存方式",
            message: "私密/本机只保留素材；可生成会用于声纹训练和语气参考；亲友仅同步元信息，音频不会被当作文字对话共享。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "私密", style: .default) { [weak self] _ in
            self?.savePickedVoiceSample(
                title: title,
                storedPath: storedPath,
                privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly),
                targetPersonName: targetPersonName
            )
        })
        alert.addAction(UIAlertAction(title: "本机", style: .default) { [weak self] _ in
            self?.savePickedVoiceSample(
                title: title,
                storedPath: storedPath,
                privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly),
                targetPersonName: targetPersonName
            )
        })
        alert.addAction(UIAlertAction(title: "可生成", style: .default) { [weak self] _ in
            self?.savePickedVoiceSample(
                title: title,
                storedPath: storedPath,
                privacyMetadata: MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeForExplicitGenerationAuthorization()),
                targetPersonName: targetPersonName
            )
        })
        alert.addAction(UIAlertAction(title: "亲友", style: .default) { [weak self] _ in
            self?.presentVoiceFamilyVisibilityChoice(title: title, storedPath: storedPath, targetPersonName: targetPersonName)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.midX,
            y: view.bounds.midY,
            width: 1,
            height: 1
        )
        present(alert, animated: true)
    }

    private func presentVoiceFamilyVisibilityChoice(
        title: String,
        storedPath: String,
        targetPersonName: String?
    ) {
        let picker = FamilyVisibilityPickerViewController()
        picker.onSelect = { [weak self] selection in
            self?.savePickedVoiceSample(
                title: title,
                storedPath: storedPath,
                privacyMetadata: MemoryPrivacyMetadata(
                    scope: MemoryPrivacyMigration.scopeForExplicitFamilyAuthorization(),
                    familyVisibility: selection.visibility
                ),
                targetPersonName: targetPersonName
            )
        }

        let navigationController = UINavigationController(rootViewController: picker)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func savePickedVoiceSample(
        title: String,
        storedPath: String,
        privacyMetadata: MemoryPrivacyMetadata,
        targetPersonName: String?
    ) {
        do {
            var item = try repository.addVoiceSample(
                localPath: storedPath,
                title: title,
                note: "导入的长辈语音样本，用于后续声纹和语气参考。",
                tags: ["语音样本"],
                isPrivate: privacyMetadata.scope == .privateOnly,
                privacyMetadata: privacyMetadata,
                targetPersonName: targetPersonName
            )
            if let profile = MemoryArchiveVoiceProfileStore.shared.registerSample(
                item,
                targetPersonName: targetPersonName
            ) {
                item = try repository.attachVoiceProfile(id: item.id, voiceProfileId: profile.id)
                handleVoiceProfileStatus(profile, latestSamplePath: storedPath)
            } else if targetPersonName != nil {
                setKnowledgeDepositStatus("声纹档案：请填写具体姓名，避免只用亲属称呼")
            }
            if item.privacyMetadata.scope != .privateOnly {
                Stage1MemoryFacade.shared.ingestArchiveVoiceSampleMetadata(
                    title: item.title,
                    note: item.note,
                    archiveItemID: item.id,
                    timestamp: item.createdAt,
                    privacyMetadata: item.privacyMetadata,
                    targetPersonName: item.targetPersonName
                ) { [weak self] addedCount in
                    DispatchQueue.main.async {
                        if addedCount == 0 {
                            self?.setKnowledgeDepositStatus("结构化建库：语音素材已保存，暂无可抽取的新知识")
                        } else {
                            self?.setKnowledgeDepositStatus("结构化建库：语音样本元信息已沉淀 \(addedCount) 条")
                        }
                    }
                }
            } else {
                setKnowledgeDepositStatus("结构化建库：私密素材仅存档案馆，不进入知识库")
            }
            syncArchiveItemMetadataToBackend(item)
            showToast("语音素材已保存", type: .success)
            reloadData()
        } catch {
            showToast("语音素材保存失败", type: .error)
        }
    }

    private func handleVoiceProfileStatus(
        _ profile: MemoryArchiveVoiceProfile,
        latestSamplePath: String
    ) {
        switch profile.status {
        case .collecting:
            setKnowledgeDepositStatus(profile.statusMessage ?? "声纹档案：继续补充语音样本")
        case .readyForTraining:
            setKnowledgeDepositStatus(profile.statusMessage ?? "声纹档案：样本已足够，开始训练")
            MemoryArchiveVoiceProfileStore.shared.startTraining(
                profileID: profile.id,
                sampleURLs: voiceSampleURLs(for: profile, latestSamplePath: latestSamplePath),
                trainer: VoiceCloneServiceProfileTrainer.shared
            ) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let trainedProfile):
                        self?.setKnowledgeDepositStatus(trainedProfile.statusMessage ?? "声纹档案：音色已就绪")
                    case .failure(let error):
                        self?.setKnowledgeDepositStatus("声纹档案：样本已保存，训练暂未完成（\(error.localizedDescription)）")
                    }
                    self?.reloadData()
                }
            }
        case .training, .ready, .failed, .disabled:
            setKnowledgeDepositStatus(profile.statusMessage ?? "声纹档案：语音样本已保存")
        }
    }

    private func voiceSampleURLs(
        for profile: MemoryArchiveVoiceProfile,
        latestSamplePath: String
    ) -> [URL] {
        let itemsByID = Dictionary(uniqueKeysWithValues: repository.items().map { ($0.id, $0) })
        let orderedPaths = profile.sampleArchiveItemIds.compactMap { sampleID -> String? in
            let path = itemsByID[sampleID]?.localPath?.trimmingCharacters(in: .whitespacesAndNewlines)
            return path?.isEmpty == false ? path : nil
        }
        let resolvedPaths = orderedPaths.isEmpty ? [latestSamplePath] : orderedPaths
        return resolvedPaths.map { URL(fileURLWithPath: $0) }
    }
}

private extension MemoryArchiveViewController {
    func setKnowledgeDepositStatus(_ text: String) {
        knowledgeDepositStatusOverride = text
        knowledgeDepositStatusLabel.text = text
    }

    func updateKnowledgeDepositStatusLabel() {
        if let knowledgeDepositStatusOverride {
            knowledgeDepositStatusLabel.text = knowledgeDepositStatusOverride
            return
        }

        let status = KBLiteDepositStatusBuilder.build(from: KBLiteManager.shared.graph)
        if status.totalEntityCount == 0 {
            knowledgeDepositStatusLabel.text = "结构化建库：暂无已沉淀知识；保存可生成/亲友素材后会整理"
        } else if status.archiveSourceCount > 0 {
            let privacyText = status.privacySummary.replacingOccurrences(of: "隐私：", with: "")
            knowledgeDepositStatusLabel.text = "结构化建库：档案 \(status.archiveSourceCount) 条 · 全库 \(status.totalEntityCount) 条 · \(privacyText)"
        } else {
            knowledgeDepositStatusLabel.text = "结构化建库：全库 \(status.totalEntityCount) 条，尚无档案来源"
        }
    }

    func refreshArchiveBackendSyncStatus() {
        guard DreamJourneyBackendClient.shared.isConfigured,
              let userId = UserManager.shared.currentUser?.id
        else {
            backendArchiveItemCount = nil
            backendArchiveLastCheckedAt = nil
            backendSyncStatusOverride = nil
            updateBackendSyncStatusLabel()
            return
        }

        DreamJourneyBackendClient.shared.fetchArchiveItems(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.backendArchiveItemCount = response.items.count
                    self?.backendArchiveLastCheckedAt = Date()
                    self?.backendSyncStatusOverride = nil
                case .failure:
                    self?.backendSyncStatusOverride = "服务器同步：暂时无法确认，素材已保留在本机"
                }
                self?.updateBackendSyncStatusLabel()
            }
        }
    }

    func updateBackendSyncStatusLabel() {
        let syncableCount = repository.items().filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .backendSync)
        }.count

        if !DreamJourneyBackendClient.shared.isConfigured {
            backendSyncStatusLabel.text = "服务器同步：未配置后端，当前仅本机保存"
            return
        }

        guard UserManager.shared.currentUser?.id != nil else {
            backendSyncStatusLabel.text = "服务器同步：登录后可同步已授权素材"
            return
        }

        if syncableCount == 0 {
            backendSyncStatusLabel.text = "服务器同步：暂无已授权素材"
            return
        }

        if let backendSyncStatusOverride {
            backendSyncStatusLabel.text = backendSyncStatusOverride
            return
        }

        if let backendArchiveItemCount {
            let checkedText: String
            if let backendArchiveLastCheckedAt {
                checkedText = Self.backendSyncDateFormatter.string(from: backendArchiveLastCheckedAt)
            } else {
                checkedText = "刚刚"
            }
            backendSyncStatusLabel.text = "服务器同步：服务器已有 \(backendArchiveItemCount) 份 · 本机已授权 \(syncableCount) 份 · \(checkedText)"
        } else {
            backendSyncStatusLabel.text = "服务器同步：\(syncableCount) 份已授权素材待确认"
        }
    }

    func syncArchiveItemMetadataToBackend(_ item: MemoryArchiveItem) {
        guard DreamJourneyBackendClient.shared.isConfigured,
              let userId = UserManager.shared.currentUser?.id,
              PrivacyScopePolicy.canUse(metadata: item.privacyMetadata, surface: .backendSync)
        else {
            return
        }

        DreamJourneyBackendClient.shared.syncArchiveItem(userId: userId, item: item) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.backendArchiveItemCount = max(
                        self?.backendArchiveItemCount ?? 0,
                        self?.repository.items().filter {
                            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .backendSync)
                        }.count ?? 0
                    )
                    self?.backendArchiveLastCheckedAt = Date()
                    self?.backendSyncStatusOverride = nil
                    self?.updateBackendSyncStatusLabel()
                case .failure(let error):
                    print("[MemoryArchive] backend metadata sync skipped/failed: \(error.localizedDescription)")
                    self?.backendSyncStatusOverride = "服务器同步：同步失败，本机副本已保存"
                    self?.updateBackendSyncStatusLabel()
                }
            }
        }
    }

    static var backendSyncDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}

extension MemoryArchiveViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: MemoryArchiveCell.reuseIdentifier,
            for: indexPath
        ) as! MemoryArchiveCell
        cell.configure(with: items[indexPath.row])
        return cell
    }
}

extension MemoryArchiveViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        112
    }
}

private struct MemoryArchiveTextDraft {
    let kind: MemoryArchiveItemKind
    let title: String
    let note: String
    let tags: [String]
    let privacyMetadata: MemoryPrivacyMetadata

    var isPrivate: Bool {
        privacyMetadata.scope == .privateOnly
    }
}

private final class MemoryArchiveTextComposerViewController: UIViewController {
    var onSave: ((MemoryArchiveTextDraft) -> Void)?

    private let kindControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["回忆", "人格提示", "口头禅"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .warmAccent
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.warmPrimary], for: .normal)
        return control
    }()

    private let titleField = MemoryArchiveTextComposerViewController.makeTextField(placeholder: "标题")

    private let noteTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .warmPrimary
        textView.backgroundColor = .warmSurface
        textView.layer.cornerRadius = 10
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.warmDivider.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        return textView
    }()

    private let privacyControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["私密", "本机", "可生成", "亲友"])
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .warmAccent
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        control.setTitleTextAttributes([.foregroundColor: UIColor.warmPrimary], for: .normal)
        return control
    }()

    private let familyVisibilityButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "person.2")
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        let button = UIButton(configuration: config)
        button.backgroundColor = .warmSurface
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 0.5
        button.layer.borderColor = UIColor.warmDivider.cgColor
        button.contentHorizontalAlignment = .leading
        button.tintColor = .warmAccent
        return button
    }()

    private lazy var familyVisibilitySection = makeSection(
        title: "亲友范围",
        view: familyVisibilityButton,
        height: 44
    )

    private var selectedFamilyVisibility = FamilyVisibilitySelection.allMembers

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground
        title = "添加素材"
        hideKeyboardWhenTapped()
        setupNavigation()
        setupLayout()
        privacyControl.addTarget(self, action: #selector(privacyChanged), for: .valueChanged)
        familyVisibilityButton.addTarget(self, action: #selector(familyVisibilityTapped), for: .touchUpInside)
        updateFamilyVisibilityState()
    }

    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "取消",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .warmAccent
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        [scrollView, stack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        stack.addArrangedSubview(makeSection(title: "素材类型", view: kindControl, height: 36))
        stack.addArrangedSubview(makeSection(title: "标题", view: titleField, height: 44))
        stack.addArrangedSubview(makeSection(title: "内容", view: noteTextView, height: 220))
        stack.addArrangedSubview(makeSection(title: "使用范围", view: privacyControl, height: 36))
        stack.addArrangedSubview(familyVisibilitySection)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func makeSection(title: String, view: UIView, height: CGFloat) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .warmSubtitle

        let stack = UIStackView(arrangedSubviews: [label, view])
        stack.axis = .vertical
        stack.spacing = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return stack
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func privacyChanged() {
        updateFamilyVisibilityState()
    }

    @objc private func familyVisibilityTapped() {
        let picker = FamilyVisibilityPickerViewController(
            initialVisibility: selectedFamilyVisibility.visibility
        )
        picker.onSelect = { [weak self] selection in
            self?.selectedFamilyVisibility = selection
            self?.updateFamilyVisibilityState()
        }
        let navigationController = UINavigationController(rootViewController: picker)
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    @objc private func saveTapped() {
        let kind: MemoryArchiveItemKind
        switch kindControl.selectedSegmentIndex {
        case 1: kind = .personalityNote
        case 2: kind = .catchphrase
        default: kind = .textNote
        }

        let draft = MemoryArchiveTextDraft(
            kind: kind,
            title: (titleField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            note: noteTextView.text.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: [kind.displayName],
            privacyMetadata: selectedPrivacyMetadata()
        )
        onSave?(draft)
    }

    private func selectedPrivacyMetadata() -> MemoryPrivacyMetadata {
        switch privacyControl.selectedSegmentIndex {
        case 1:
            return MemoryPrivacyMetadata(scope: .localOnly)
        case 2:
            return MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeForExplicitGenerationAuthorization())
        case 3:
            return MemoryPrivacyMetadata(
                scope: MemoryPrivacyMigration.scopeForExplicitFamilyAuthorization(),
                familyVisibility: selectedFamilyVisibility.visibility
            )
        default:
            return MemoryPrivacyMetadata(scope: .privateOnly)
        }
    }

    private func updateFamilyVisibilityState() {
        familyVisibilitySection.isHidden = privacyControl.selectedSegmentIndex != 3

        var config = familyVisibilityButton.configuration ?? .plain()
        config.title = selectedFamilyVisibility.summary
        config.baseForegroundColor = .warmPrimary
        familyVisibilityButton.configuration = config
    }

    private static func makeTextField(placeholder: String) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16)
        field.textColor = .warmPrimary
        field.backgroundColor = .warmSurface
        field.layer.cornerRadius = 10
        field.layer.borderWidth = 0.5
        field.layer.borderColor = UIColor.warmDivider.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        field.rightViewMode = .always
        field.clearButtonMode = .whileEditing
        return field
    }
}

private final class MemoryArchiveCell: UITableViewCell {
    static let reuseIdentifier = "MemoryArchiveCell"

    private let surface = UIView()
    private let thumbnailView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: MemoryArchiveItem) {
        titleLabel.text = item.title
        detailLabel.text = item.displayDetail
        statusLabel.text = item.statusText
        statusLabel.textColor = item.statusColor

        if (item.kind == .photo || item.kind == .screenshot),
           let path = item.localPath,
           let image = UIImage(contentsOfFile: path) {
            thumbnailView.image = image
            thumbnailView.tintColor = nil
            thumbnailView.backgroundColor = .clear
        } else {
            thumbnailView.image = UIImage(systemName: item.kind.iconName)
            thumbnailView.tintColor = .warmAccent
            thumbnailView.backgroundColor = UIColor.warmAccent.withAlphaComponent(0.12)
        }
    }

    private func setupView() {
        backgroundColor = .clear
        selectionStyle = .none

        surface.backgroundColor = .warmSurface
        surface.layer.cornerRadius = 12
        surface.layer.borderWidth = 0.5
        surface.layer.borderColor = UIColor.warmDivider.cgColor

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 8

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .warmPrimary
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .warmSubtitle
        detailLabel.numberOfLines = 2
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)

        contentView.addSubview(surface)
        [thumbnailView, titleLabel, detailLabel, statusLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            surface.addSubview($0)
        }
        surface.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            surface.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            surface.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            surface.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            thumbnailView.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: surface.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 72),
            thumbnailView.heightAnchor.constraint(equalToConstant: 72),

            statusLabel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -14),

            titleLabel.topAnchor.constraint(equalTo: surface.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusLabel.leadingAnchor, constant: -10),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
        ])
    }
}

private extension MemoryArchiveItemKind {
    var displayName: String {
        switch self {
        case .photo: return "旧照片"
        case .screenshot: return "聊天截图"
        case .voiceSample: return "语音样本"
        case .textNote: return "文字回忆"
        case .personalityNote: return "人格提示"
        case .catchphrase: return "口头禅"
        }
    }

    var iconName: String {
        switch self {
        case .photo: return "photo"
        case .screenshot: return "text.viewfinder"
        case .voiceSample: return "waveform"
        case .textNote: return "text.alignleft"
        case .personalityNote: return "person.text.rectangle"
        case .catchphrase: return "quote.bubble"
        }
    }
}

private extension MemoryArchiveItem {
    var displayDetail: String {
        if let summary = analysisSummary, !summary.isEmpty {
            return summary
        }
        if !note.isEmpty {
            return note
        }
        return kind.displayName
    }

    var statusText: String {
        switch analysisStatus {
        case .manual: return kind.displayName
        case .pending: return "分析中"
        case .analyzed: return "已分析"
        case .failed: return "待补充"
        }
    }

    var statusColor: UIColor {
        switch analysisStatus {
        case .manual: return .warmPrimary
        case .pending: return .warmSubtitle
        case .analyzed: return .warmAccent
        case .failed: return .warmSubtitle
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
