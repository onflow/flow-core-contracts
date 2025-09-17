import "FlowTransactionSchedulerUtils"

access(all) fun main(address: Address, id: UInt64): UInt8? {
    let managerRef = FlowTransactionSchedulerUtils.borrowManager(at: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    return managerRef.getTransactionStatus(id: id)?.rawValue
}