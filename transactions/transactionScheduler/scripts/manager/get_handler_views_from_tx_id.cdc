import "FlowTransactionSchedulerUtils"

access(all) fun main(address: Address, id: UInt64): [Type] {
    let managerRef = FlowTransactionSchedulerUtils.borrowManager(at: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    return managerRef.getHandlerViewsFromTransactionID(id)
}