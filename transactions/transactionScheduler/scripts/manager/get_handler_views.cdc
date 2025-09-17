import "FlowTransactionSchedulerUtils"

access(all) fun main(address: Address, handlerTypeIdentifier: String, handlerUUID: UInt64?): [Type] {
    let managerRef = FlowTransactionSchedulerUtils.getManager(address: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    return managerRef.getHandlerViews(handlerTypeIdentifier: handlerTypeIdentifier, handlerUUID: handlerUUID)
}