import "FlowTransactionSchedulerUtils"

access(all) fun main(address: Address, id: UInt64, viewType: Type): AnyStruct? {
    let managerRef = FlowTransactionSchedulerUtils.getManager(address: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    return managerRef.resolveHandlerViewFromTransactionID(transactionId: id, viewType: viewType)
}