/*
 * Original work Copyright 2024 LiveKit, Inc.
 * Modifications Copyright 2025 Eleven Labs Inc.
 * Licensed under the Apache License, Version 2.0.
 * http://www.apache.org/licenses/LICENSE-2.0
 * Distributed on an AS IS BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND.
 * DreamJourney adaptation: UIKit lifecycle, real PCM envelopes and blue-white rendering.
 */
import UIKit
import MetalKit

/// Rendering adapted from ElevenLabs components-swift (Apache-2.0).
/// See EchoOrb-NOTICE.txt and EchoOrb-LICENSE.txt bundled with the app.
/// Six 16-byte groups match the Metal struct exactly (96 bytes).
struct EchoOrbUniforms {
    var timing = SIMD4<Float>(repeating: 0)
    var offsetsA = SIMD4<Float>(0.2, 1.4, 2.7, 3.6)
    var offsetsB = SIMD4<Float>(4.8, 5.2, 6.0, 0)
    var color1 = SIMD4<Float>(0.16, 0.48, 0.91, 1)
    var color2 = SIMD4<Float>(0.73, 0.91, 1, 1)
    var volumes = SIMD4<Float>(repeating: 0)
}

final class EchoCloudOrbView: UIView, MTKViewDelegate {
    private var metalView: MTKView?
    private var commandQueue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    private let fallback = CAGradientLayer()
    private var input = EchoOrbEnvelope()
    private var output = EchoOrbEnvelope()
    private var uniforms = EchoOrbUniforms()
    private var lastFrame: TimeInterval?
    private var animationTime: Float = 0
    private var applicationActive = true
    private var acceptsSamplesAfter: TimeInterval = 0
    var active = false { didSet { if active != oldValue { resetAudio(); updateMotion() } } }
    var speaking = false { didSet { if !speaking { resetAudio() } } }
    var color1 = SIMD4<Float>(0.16, 0.48, 0.91, 1) { didSet { uniforms.color1 = color1; redrawStatic() } }
    var color2 = SIMD4<Float>(0.73, 0.91, 1, 1) { didSet { uniforms.color2 = color2; redrawStatic() } }
    var hasMetalRenderer: Bool { pipeline != nil }
    private(set) var renderedLevels = SIMD2<Float>(repeating: 0)

    override convenience init(frame: CGRect) { self.init(frame: frame, allowsMetal: true) }
    init(frame: CGRect, allowsMetal: Bool) {
        super.init(frame: frame)
        isUserInteractionEnabled = false; isAccessibilityElement = false
        fallback.type = .radial
        fallback.colors = [UIColor.white.cgColor, UIColor(red: 0.45, green: 0.77, blue: 1, alpha: 1).cgColor,
                           UIColor(red: 0.16, green: 0.48, blue: 0.91, alpha: 1).cgColor]
        fallback.startPoint = CGPoint(x: 0.35, y: 0.3); fallback.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(fallback)
        if allowsMetal, let device = MTLCreateSystemDefaultDevice(),
           let queue = device.makeCommandQueue(), let library = device.makeDefaultLibrary(),
           let vertex = library.makeFunction(name: "echoOrbVertexShader"),
           let fragment = library.makeFunction(name: "echoOrbFragmentShader") {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex; descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            if let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) {
                self.pipeline = pipeline; commandQueue = queue
                let view = MTKView(frame: .zero, device: device)
                view.isOpaque = false; view.backgroundColor = .clear
                view.clearColor = MTLClearColorMake(0, 0, 0, 0)
                view.framebufferOnly = true; view.autoResizeDrawable = false
                view.isPaused = true; view.enableSetNeedsDisplay = false; view.delegate = self
                addSubview(view); metalView = view; fallback.isHidden = true
            }
        }
        for name in [UIAccessibility.reduceMotionStatusDidChangeNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange] {
            NotificationCenter.default.addObserver(self, selector: #selector(updateMotion), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    override func didMoveToWindow() { super.didMoveToWindow(); resetAudio(); updateMotion() }
    override func layoutSubviews() {
        super.layoutSubviews()
        let side = min(bounds.width, bounds.height)
        let frame = CGRect(x: (bounds.width-side)/2, y: (bounds.height-side)/2, width: side, height: side)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        fallback.frame = frame; fallback.cornerRadius = side / 2; fallback.masksToBounds = true
        CATransaction.commit()
        metalView?.frame = frame
        let pixels = min(600, side * (window?.screen.scale ?? 2))
        metalView?.drawableSize = CGSize(width: max(1, pixels), height: max(1, pixels))
        redrawStatic()
    }
    func receiveAudioLevel(_ level: Float, channel: DialogOrbAudioChannel, capturedAt: TimeInterval) {
        let now = ProcessInfo.processInfo.systemUptime
        guard active, speaking, applicationActive, window != nil,
              capturedAt >= acceptsSamplesAfter, now >= capturedAt, now - capturedAt <= 0.18 else { return }
        switch channel {
        case .input: input.receive(level, at: capturedAt)
        case .output: output.receive(level, at: capturedAt)
        }
    }
    func resetAudio() {
        input.reset(); output.reset(); renderedLevels = .zero; uniforms.volumes = .zero
        acceptsSamplesAfter = ProcessInfo.processInfo.systemUptime
    }
    @objc private func background() { applicationActive = false; resetAudio(); updateMotion() }
    @objc private func foreground() { applicationActive = true; resetAudio(); updateMotion() }
    @objc private func updateMotion() {
        resetAudio(); lastFrame = nil
        metalView?.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 15 : 30
        metalView?.isPaused = !active || !applicationActive || window == nil || UIAccessibility.isReduceMotionEnabled
        redrawStatic()
    }
    private func redrawStatic() { if metalView?.isPaused == true { metalView?.draw() } }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        let now = ProcessInfo.processInfo.systemUptime
        if !UIAccessibility.isReduceMotionEnabled && active && applicationActive {
            renderedLevels = SIMD2(input.advance(at: now), output.advance(at: now))
            let delta = Float(min(0.1, max(0, now - (lastFrame ?? now))))
            animationTime += delta * (0.18 + renderedLevels.x * 0.8 + renderedLevels.y * 1.2)
        } else { renderedLevels = .zero }
        lastFrame = now
        uniforms.timing.x = animationTime * 6; uniforms.timing.y = animationTime
        uniforms.volumes.x = renderedLevels.x; uniforms.volumes.y = renderedLevels.y
        guard let drawable = view.currentDrawable, let descriptor = view.currentRenderPassDescriptor,
              let pipeline, let command = commandQueue?.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        let vertices: [Float] = [-1,1, -1,-1, 1,1, 1,-1]
        encoder.setRenderPipelineState(pipeline)
        vertices.withUnsafeBytes { encoder.setVertexBytes($0.baseAddress!, length: $0.count, index: 0) }
        var values = uniforms
        encoder.setFragmentBytes(&values, length: MemoryLayout<EchoOrbUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding(); command.present(drawable); command.commit()
    }
}

/// Four visible lines, full text retained. Reading older lines disables tail-follow.
final class EchoReplyTextView: UITextView, UITextViewDelegate {
    private(set) var followsTail = true
    private var measuredWidth: CGFloat = 0
    override var text: String! {
        didSet {
            invalidateIntrinsicContentSize()
            if followsTail { DispatchQueue.main.async { [weak self] in
                guard let self, self.followsTail, !self.text.isEmpty else { return }
                self.scrollRangeToVisible(NSRange(location: (self.text as NSString).length - 1, length: 1))
            } }
        }
    }
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        isEditable = false; isSelectable = true; backgroundColor = .clear
        self.textContainerInset = .zero; self.textContainer.lineFragmentPadding = 0
        font = UIFontMetrics(forTextStyle: .body).scaledFont(for: DJDesignTokens.Font.body(17))
        adjustsFontForContentSizeCategory = true
        textColor = DJDesignTokens.Color.textSecondary; delegate = self
        accessibilityIdentifier = "echoCurrentReply"
        setContentCompressionResistancePriority(.required, for: .vertical)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: CGSize {
        let line = font?.lineHeight ?? 22
        let width = max(1, bounds.width)
        let height = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: UIView.noIntrinsicMetric, height: min(line * 4, max(line, height)))
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        if abs(measuredWidth - bounds.width) > 0.5 {
            measuredWidth = bounds.width; invalidateIntrinsicContentSize()
        }
    }
    func beginReply() { followsTail = true }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { followsTail = false }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { updateFollow() }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { updateFollow() }
    private func updateFollow() { followsTail = contentOffset.y + bounds.height >= contentSize.height - 4 }
}

final class EchoComposerView: UIView, UITextFieldDelegate {
    let field = UITextField()
    let send = UIButton(type: .system)
    var onSend: ((String) -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = DJDesignTokens.Color.surface
        layer.cornerRadius = 28
        layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.25).cgColor
        layer.borderWidth = 1
        field.placeholder = "发消息，或开启语音对话"
        field.font = UIFontMetrics.default.scaledFont(for: DJDesignTokens.Font.body())
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .send; field.delegate = self
        field.accessibilityIdentifier = "echoTextQuestionField"
        send.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        send.tintColor = DJDesignTokens.Color.accentDeep
        send.accessibilityLabel = "发送文字"
        send.addTarget(self, action: #selector(submit), for: .touchUpInside)
        [field, send].forEach { addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            field.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            field.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            send.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 4),
            send.widthAnchor.constraint(equalToConstant: 44), send.heightAnchor.constraint(equalToConstant: 44),
            send.centerYAnchor.constraint(equalTo: centerYAnchor),
            send.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -64)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func submit() {
        guard !isHidden, isUserInteractionEnabled, let text = field.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onSend?(text)
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { submit(); return false }
}

/// UI-only view of a read result; no business retry authority.
struct EchoOrganizationPresentation: Equatable {
    enum Phase { case organizing, completed, incomplete }
    let phase: Phase
    let text: String
    static func capture(_ state: EchoLiveMemoryCaptureState, partial: Bool = false) -> Self? {
        switch state {
        case .live: return nil
        case .pendingReview: return Self(phase: .completed, text: partial
            ? "整理完成，已存入待确认记忆\n少量内容暂未整理完成" : "整理完成，已存入待确认记忆")
        case .empty: return Self(phase: .completed, text: "整理完成，本次没有新增记忆")
        case .terminalFailure, .quarantined: return Self(phase: .incomplete, text: "整理暂未完成")
        case .statusUnknown, .unavailable, .syncPaused:
            return Self(phase: .organizing, text: "正在整理\n暂时无法获取进度，联网后会自动核对")
        default: return Self(phase: .organizing, text: "正在整理")
        }
    }
}

/// One request at a time, foreground only. The request closure must be status-only.
final class EchoPublicationObserver {
    typealias Request = (@escaping (Result<OwnerTruthLiveRecoveryProgress, Error>) -> Void) -> Void
    private let request: Request
    private let schedule: (TimeInterval, @escaping () -> Void) -> DispatchWorkItem
    var onProgress: ((OwnerTruthLiveRecoveryProgress) -> Void)?
    var onUnavailable: (() -> Void)?
    private var timer: DispatchWorkItem?
    private var deadline: DispatchWorkItem?
    private var generation = UUID()
    private var inFlight = false
    private(set) var latest: OwnerTruthLiveRecoveryProgress?
    private(set) var active = false
    private var count = 0
    init(initial: OwnerTruthLiveRecoveryProgress?, request: @escaping Request,
         schedule: @escaping (TimeInterval, @escaping () -> Void) -> DispatchWorkItem = { delay, action in
             let item = DispatchWorkItem(block: action)
             DispatchQueue.main.asyncAfter(deadline: .now()+delay, execute: item); return item
         }) {
        latest = initial; self.request = request; self.schedule = schedule
    }
    deinit { timer?.cancel(); deadline?.cancel() }
    func start() {
        guard !active else { return }; active = true
        if let latest, Self.settled(latest) { onProgress?(latest); return }
        read()
    }
    func suspend() {
        active = false; generation = UUID()
        timer?.cancel(); deadline?.cancel(); timer = nil; deadline = nil
    }
    private static func settled(_ value: OwnerTruthLiveRecoveryProgress) -> Bool {
        guard let publication = value.publication else { return false }
        return ["published", "noChange", "failed"].contains(publication.state)
    }
    private func read() {
        guard active, !inFlight else { return }
        inFlight = true; let token = UUID(); generation = token
        deadline = schedule(15) { [weak self] in
            guard let self, self.generation == token, self.inFlight else { return }
            if self.active { self.onUnavailable?() }
            // Keep the transport slot occupied until its bounded HTTP completion.
            // A UI observation deadline must never create overlapping requests.
        }
        request { [weak self] result in
            guard let self else { return }
            self.inFlight = false; self.deadline?.cancel()
            guard self.active else { return }
            guard self.generation == token else { self.read(); return }
            if case .success(let value) = result {
                if let old = self.latest {
                    guard value.sessionId == old.sessionId, value.generation == old.generation,
                          value.version >= old.version,
                          value.snapshotRevision >= old.snapshotRevision else { self.next(); return }
                    // Success for this snapshot cannot regress due to a late/legacy failure.
                    if ["published", "noChange"].contains(old.publication?.state ?? ""),
                       value.publication?.snapshotRevision == old.publication?.snapshotRevision {
                        return
                    }
                }
                self.latest = value; self.onProgress?(value)
                if Self.settled(value) { return }
            } else { self.onUnavailable?() }
            self.next()
        }
    }
    private func next() {
        guard active else { return }; count += 1
        // A bounded fast round, then low-frequency observation while visible.
        let delay: TimeInterval = count < 12 ? 15 : (count < 24 ? 60 : 120)
        timer?.cancel(); timer = schedule(delay) { [weak self] in self?.read() }
    }
}
