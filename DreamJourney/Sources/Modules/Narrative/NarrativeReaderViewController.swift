import UIKit

final class NarrativeReaderViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private struct Page: Sendable {
        let chapterKey: String
        let chapterVersionId: String
        let title: String
        let paragraphId: String
        let text: String
        let characterOffset: Int
    }

    private let project: NarrativeProject
    private let subjectPersonaId: String
    private let accountLease: AccountLease
    private let service: NarrativeBackendServicePort
    private let stateStore: NarrativeReaderStateStore
    private var readingState: NarrativeReadingState
    private var manifest: NarrativeReaderManifest?
    private var pages: [Page] = []
    private var chapters: [String: NarrativeReaderChapter] = [:]
    private var collectionView: UICollectionView!
    private let toolbar = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
    private let pageLabel = UILabel()
    private let loading = UIActivityIndicatorView(style: .large)
    private var lastPaginationSize: CGSize = .zero
    private var paginationGeneration = 0

    init(
        project: NarrativeProject,
        subjectPersonaId: String,
        accountLease: AccountLease,
        service: NarrativeBackendServicePort,
        stateStore: NarrativeReaderStateStore = .shared
    ) {
        self.project = project
        self.subjectPersonaId = subjectPersonaId
        self.accountLease = accountLease
        self.service = service
        self.stateStore = stateStore
        self.readingState = stateStore.load(projectId: project.projectId, accountLease: accountLease)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = project.title
        configureCollectionView()
        configureToolbar()
        applyAppearance()
        loading.startAnimating()
        view.addSubview(loading)
        loading.center = view.center
        loadManifest()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = collectionView.bounds.size
        guard !chapters.isEmpty,
              size.width > 0,
              size.height > 0,
              abs(size.width - lastPaginationSize.width) > 1
                || abs(size.height - lastPaginationSize.height) > 1 else { return }
        persistVisibleAnchor()
        rebuildPages()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory,
           !chapters.isEmpty {
            persistVisibleAnchor()
            rebuildPages()
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { pages.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NarrativePageCell", for: indexPath) as! NarrativePageCell
        let page = pages[indexPath.item]
        cell.configure(title: page.title, text: page.text, fontSize: CGFloat(readingState.fontScale.pointSize), colors: colors())
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { persistVisibleAnchor() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { persistVisibleAnchor() }

    private func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(NarrativePageCell.self, forCellWithReuseIdentifier: "NarrativePageCell")
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(readerTapped(_:)))
        collectionView.addGestureRecognizer(tap)
    }

    private func configureToolbar() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalCentering
        stack.alignment = .center
        let contents = iconButton("list.bullet", action: #selector(contentsTapped))
        let settings = iconButton("textformat.size", action: #selector(settingsTapped))
        pageLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        stack.addArrangedSubview(contents)
        stack.addArrangedSubview(pageLabel)
        stack.addArrangedSubview(settings)
        toolbar.contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: toolbar.contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: toolbar.contentView.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: toolbar.contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: toolbar.contentView.bottomAnchor, constant: -10),
        ])
        toolbar.layer.cornerRadius = 6
        toolbar.clipsToBounds = true
        view.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    private func loadManifest() {
        service.readerManifest(accountLease: accountLease, projectId: project.projectId, subjectPersonaId: subjectPersonaId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let manifest):
                self.manifest = manifest
                self.loadChapters(manifest.chapters, index: 0)
            case .failure(let error): self.show(error)
            }
        }
    }

    private func loadChapters(_ values: [NarrativeReaderChapterSummary], index: Int) {
        guard index < values.count else {
            rebuildPages()
            return
        }
        let item = values[index]
        service.readerChapter(accountLease: accountLease, projectId: project.projectId, chapterKey: item.chapterKey, subjectPersonaId: subjectPersonaId) { [weak self] result in
            guard let self else { return }
            if case .success(let chapter) = result { self.chapters[chapter.chapterKey] = chapter }
            self.loadChapters(values, index: index + 1)
        }
    }

    private func rebuildPages() {
        let prior = readingState.anchor
        let paginationSize = collectionView.bounds.size
        guard paginationSize.width > 0, paginationSize.height > 0 else { return }
        lastPaginationSize = paginationSize
        paginationGeneration += 1
        let generation = paginationGeneration
        let containerSize = CGSize(
            width: max(240, paginationSize.width - 64),
            height: max(320, paginationSize.height - 150)
        )
        let fontSize = CGFloat(readingState.fontScale.pointSize)
        let summaries = manifest?.chapters ?? []
        let chapterLookup = chapters
        loading.startAnimating()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let baseFont = UIFont(name: "Songti SC", size: fontSize)
                ?? .systemFont(ofSize: fontSize)
            let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
            let newPages = summaries.flatMap { summary -> [Page] in
                guard let chapter = chapterLookup[summary.chapterKey] else { return [] }
                return chapter.paragraphs.flatMap { paragraph in
                    NarrativeTextPaginator.fragments(
                        text: paragraph.text,
                        font: font,
                        containerSize: containerSize
                    ).map { fragment in
                        Page(
                            chapterKey: chapter.chapterKey,
                            chapterVersionId: chapter.chapterVersionId,
                            title: chapter.title,
                            paragraphId: paragraph.paragraphId,
                            text: fragment.text,
                            characterOffset: fragment.offset
                        )
                    }
                }
            }
            DispatchQueue.main.async {
                guard let self, self.paginationGeneration == generation else { return }
                self.pages = newPages
                self.collectionView.reloadData()
                let target = prior.flatMap { anchor in
                    newPages.indices.reversed().first {
                        newPages[$0].chapterKey == anchor.chapterKey
                            && newPages[$0].paragraphId == anchor.paragraphId
                            && newPages[$0].characterOffset <= anchor.characterOffset
                    }
                } ?? 0
                if newPages.indices.contains(target) {
                    self.collectionView.scrollToItem(
                        at: IndexPath(item: target, section: 0),
                        at: .centeredHorizontally,
                        animated: false
                    )
                }
                self.updatePageLabel(index: target)
                self.loading.stopAnimating()
            }
        }
    }

    private func persistVisibleAnchor() {
        guard let index = collectionView.indexPathsForVisibleItems.sorted().first?.item,
              pages.indices.contains(index) else { return }
        let page = pages[index]
        readingState.anchor = NarrativeSemanticAnchor(
            chapterKey: page.chapterKey,
            chapterVersionId: page.chapterVersionId,
            paragraphId: page.paragraphId,
            characterOffset: page.characterOffset
        )
        stateStore.save(readingState, projectId: project.projectId, accountLease: accountLease)
        title = "\(project.title) · \(page.title)"
        updatePageLabel(index: index)
    }

    private func updatePageLabel(index: Int) { pageLabel.text = pages.isEmpty ? "0 / 0" : "\(index + 1) / \(pages.count)" }

    @objc private func readerTapped(_ gesture: UITapGestureRecognizer) {
        let x = gesture.location(in: view).x
        let width = view.bounds.width
        if x < width * 0.28 { movePage(delta: -1) }
        else if x > width * 0.72 { movePage(delta: 1) }
        else { toolbar.isHidden.toggle() }
    }

    private func movePage(delta: Int) {
        let current = collectionView.indexPathsForVisibleItems.sorted().first?.item ?? 0
        let target = min(max(0, current + delta), max(0, pages.count - 1))
        guard pages.indices.contains(target) else { return }
        collectionView.scrollToItem(at: IndexPath(item: target, section: 0), at: .centeredHorizontally, animated: true)
    }

    @objc private func contentsTapped() {
        guard let manifest else { return }
        let currentKey = collectionView.indexPathsForVisibleItems.sorted().first
            .flatMap { pages.indices.contains($0.item) ? pages[$0.item].chapterKey : nil }
        let controller = NarrativeContentsViewController(
            chapters: manifest.chapters,
            currentChapterKey: currentKey
        ) { [weak self] key in
            guard let self, let index = self.pages.firstIndex(where: { $0.chapterKey == key }) else { return }
            self.collectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
        }
        present(UINavigationController(rootViewController: controller), animated: true)
    }

    @objc private func settingsTapped() {
        let controller = NarrativeReaderSettingsViewController(state: readingState) { [weak self] state in
            guard let self else { return }
            self.readingState = state
            self.stateStore.save(state, projectId: self.project.projectId, accountLease: self.accountLease)
            self.applyAppearance()
            self.rebuildPages()
        }
        present(controller, animated: true)
    }

    private func applyAppearance() { let value = colors(); view.backgroundColor = value.background; collectionView.backgroundColor = value.background }
    private func colors() -> (background: UIColor, text: UIColor) {
        switch readingState.background {
        case .paper: return (UIColor(red: 0.98, green: 0.96, blue: 0.91, alpha: 1), UIColor(red: 0.13, green: 0.11, blue: 0.09, alpha: 1))
        case .warm: return (UIColor(red: 0.94, green: 0.88, blue: 0.77, alpha: 1), UIColor(red: 0.19, green: 0.14, blue: 0.09, alpha: 1))
        case .green: return (UIColor(red: 0.82, green: 0.88, blue: 0.79, alpha: 1), UIColor(red: 0.10, green: 0.18, blue: 0.12, alpha: 1))
        case .night: return (UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1), UIColor(red: 0.80, green: 0.81, blue: 0.78, alpha: 1))
        }
    }

    private func iconButton(_ name: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: name), for: .normal)
        button.accessibilityLabel = name == "list.bullet" ? "目录" : "阅读设置"
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    private func show(_ error: Error) {
        loading.stopAnimating()
        let alert = UIAlertController(title: "无法打开书稿", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "返回", style: .default) { [weak self] _ in self?.navigationController?.popViewController(animated: true) })
        present(alert, animated: true)
    }
}

private final class NarrativePageCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    private let textLabel = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        textLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, textLabel])
        stack.axis = .vertical
        stack.spacing = 24
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 44),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.safeAreaLayoutGuide.bottomAnchor, constant: -78),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(title: String, text: String, fontSize: CGFloat, colors: (background: UIColor, text: UIColor)) {
        backgroundColor = colors.background
        titleLabel.text = title
        titleLabel.textColor = colors.text.withAlphaComponent(0.62)
        textLabel.text = text
        let base = UIFont(name: "Songti SC", size: fontSize) ?? .systemFont(ofSize: fontSize)
        textLabel.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
        textLabel.adjustsFontForContentSizeCategory = true
        textLabel.textColor = colors.text
        textLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
}

enum NarrativeTextPaginator {
    struct Fragment: Sendable {
        let text: String
        let offset: Int
    }

    static func fragments(
        text: String,
        font: UIFont,
        containerSize: CGSize
    ) -> [Fragment] {
        let source = text as NSString
        guard source.length > 0 else { return [] }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        paragraph.paragraphSpacing = 10
        let storage = NSTextStorage(
            string: text,
            attributes: [.font: font, .paragraphStyle: paragraph]
        )
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        var fragments: [Fragment] = []
        var glyphOffset = 0
        while glyphOffset < layoutManager.numberOfGlyphs {
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            container.maximumNumberOfLines = 0
            layoutManager.addTextContainer(container)
            let glyphRange = layoutManager.glyphRange(for: container)
            guard glyphRange.length > 0 else { break }
            let characterRange = layoutManager.characterRange(
                forGlyphRange: glyphRange,
                actualGlyphRange: nil
            )
            fragments.append(Fragment(
                text: source.substring(with: characterRange),
                offset: characterRange.location
            ))
            glyphOffset = NSMaxRange(glyphRange)
        }
        return fragments.isEmpty ? [Fragment(text: text, offset: 0)] : fragments
    }
}

private final class NarrativeContentsViewController: UITableViewController {
    private let chapters: [NarrativeReaderChapterSummary]
    private let currentChapterKey: String?
    private let selection: (String) -> Void
    init(
        chapters: [NarrativeReaderChapterSummary],
        currentChapterKey: String?,
        selection: @escaping (String) -> Void
    ) {
        self.chapters = chapters
        self.currentChapterKey = currentChapterKey
        self.selection = selection
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad(); title = "目录"; navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }) }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { chapters.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { let cell = UITableViewCell(style: .value1, reuseIdentifier: nil); let chapter = chapters[indexPath.row]; cell.textLabel?.text = chapter.title; cell.detailTextLabel?.text = "第 \(indexPath.row + 1) 章"; cell.accessoryType = chapter.chapterKey == currentChapterKey ? .checkmark : .none; return cell }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { selection(chapters[indexPath.row].chapterKey); dismiss(animated: true) }
}

private final class NarrativeReaderSettingsViewController: UIViewController {
    private var state: NarrativeReadingState
    private let completion: (NarrativeReadingState) -> Void
    init(state: NarrativeReadingState, completion: @escaping (NarrativeReadingState) -> Void) { self.state = state; self.completion = completion; super.init(nibName: nil, bundle: nil); modalPresentationStyle = .pageSheet }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        let font = UISegmentedControl(items: ["小", "较小", "标准", "大", "特大"])
        font.selectedSegmentIndex = NarrativeReaderFontScale.allCases.firstIndex(of: state.fontScale) ?? 2
        font.addTarget(self, action: #selector(fontChanged(_:)), for: .valueChanged)
        let background = UISegmentedControl(items: ["纸张", "暖色", "护眼", "夜间"])
        background.selectedSegmentIndex = NarrativeReaderBackground.allCases.firstIndex(of: state.background) ?? 0
        background.addTarget(self, action: #selector(backgroundChanged(_:)), for: .valueChanged)
        let done = UIButton(type: .system); done.setTitle("完成", for: .normal); done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold); done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [font, background, done]); stack.axis = .vertical; stack.spacing = 24
        view.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28), stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)])
    }
    @objc private func fontChanged(_ sender: UISegmentedControl) { state.fontScale = NarrativeReaderFontScale.allCases[sender.selectedSegmentIndex] }
    @objc private func backgroundChanged(_ sender: UISegmentedControl) { state.background = NarrativeReaderBackground.allCases[sender.selectedSegmentIndex] }
    @objc private func doneTapped() { completion(state); dismiss(animated: true) }
}
