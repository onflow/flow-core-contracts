import "FlowTransactionSchedulerUtils"

access(all) fun main(address: Address, timestamp: UFix64): [UInt64] {
    let managerRef = FlowTransactionSchedulerUtils.borrowManager(at: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    return managerRef.getTransactionIDsByTimestamp(timestamp)
}