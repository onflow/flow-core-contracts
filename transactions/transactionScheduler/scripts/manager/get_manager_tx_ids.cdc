import "FlowTransactionSchedulerUtils"

access(all) fun main(address: Address): [UInt64] {
    let managerRef = FlowTransactionSchedulerUtils.getManager(address: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    return managerRef.getTransactionIDs()
}