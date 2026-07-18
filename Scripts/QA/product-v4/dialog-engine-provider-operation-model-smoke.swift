import Foundation

struct CallbackContext: Equatable {
    let engineGeneration: Int
    let operationID: Int
}

struct ProviderOperationModel {
    private(set) var engineGeneration = 1
    private(set) var activeOperationID: Int?
    private(set) var requiresEngineRecreationBeforeNextDialog = false
    private var nextOperationID = 1

    mutating func start() -> CallbackContext {
        if requiresEngineRecreationBeforeNextDialog {
            engineGeneration += 1
            requiresEngineRecreationBeforeNextDialog = false
        }
        let operationID = nextOperationID
        nextOperationID += 1
        activeOperationID = operationID
        return CallbackContext(engineGeneration: engineGeneration, operationID: operationID)
    }

    mutating func stop() {
        activeOperationID = nil
        requiresEngineRecreationBeforeNextDialog = true
    }

    func accepts(_ callback: CallbackContext) -> Bool {
        callback.engineGeneration == engineGeneration
            && callback.operationID == activeOperationID
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

var model = ProviderOperationModel()
let first = model.start()
require(model.accepts(first), "the active operation callback should be accepted")

model.stop()
let second = model.start()
require(first.engineGeneration != second.engineGeneration, "restart after stop must rotate engine generation")
require(!model.accepts(first), "a late terminal callback from the retired provider session must be rejected")
require(model.accepts(second), "the replacement operation callback should be accepted")

print("Dialog engine provider operation model smoke passed")
