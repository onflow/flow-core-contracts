import "FlowTransactionSchedulerUtils"
import "FlowTransactionScheduler"

access(all) fun main(address: Address, id: UInt64): FlowTransactionScheduler.TransactionData? {
    let managerRef = FlowTransactionSchedulerUtils.borrowManager(at: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    if let txData = managerRef.getTransactionData(id) {
        return txData
    }
    return nil
}