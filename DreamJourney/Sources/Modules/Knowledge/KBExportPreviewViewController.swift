import UIKit
import PDFKit

// MARK: - KBExportPreviewViewController

/// 家谱 PDF 预览页 — 使用 PDFKit 加载并展示生成的 PDF
final class KBExportPreviewViewController: UIViewController {

    // MARK: - Properties

    private let pdfURL: URL

    // MARK: - UI

    private lazy var pdfView: PDFView = {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .warmBackground
        return view
    }()

    private lazy var shareButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("分享", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.backgroundColor = UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0)
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("保存到文件", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.backgroundColor = UIColor(red: 0.87, green: 0.83, blue: 0.78, alpha: 1.0)
        btn.setTitleColor(UIColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1.0), for: .normal)
        btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(saveToFilesTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var buttonStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [shareButton, saveButton])
        stack.axis = .horizontal
        stack.spacing = 16
        stack.distribution = .fillEqually
        return stack
    }()

    // MARK: - Init

    init(pdfURL: URL) {
        self.pdfURL = pdfURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "家谱预览"
        view.backgroundColor = .warmBackground
        setupLayout()
        loadPDF()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(pdfView)
        view.addSubview(buttonStack)

        [pdfView, buttonStack].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -12),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            buttonStack.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func loadPDF() {
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
        }
    }

    // MARK: - Actions

    @objc private func shareTapped() {
        let activityVC = UIActivityViewController(activityItems: [pdfURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activityVC, animated: true)
    }

    @objc private func saveToFilesTapped() {
        let documentPicker = UIDocumentPickerViewController(forExporting: [pdfURL], asCopy: true)
        present(documentPicker, animated: true)
    }
}
