import Foundation

// MARK: - DialogEngineProtocol

protocol DialogEngineProtocol: AnyObject {
    var delegate: DialogEngineDelegate? { get set }
    var isEngineReady: Bool { get }
    var isDialogActive: Bool { get }

    func setup()
    func startDialog()
    func stopDialog(reason: DialogEndReason)
    func destroyEngine()
}

extension DialogEngineProtocol {
    func stopDialog() {
        stopDialog(reason: .manual)
    }
}
