import "FlowTransactionSchedulerUtils"
import "FlowTransactionScheduler"

access(all) fun main(address: Address, id: UInt64): FlowTransactionScheduler.TransactionData {
    let managerRef = FlowTransactionSchedulerUtils.getManager(address: address)
        ?? panic("Invalid address: Could not borrow a reference to the Scheduled Transaction Manager at address \(address)")
    let txData = managerRef.getTransactionData(id: id)
        ?? panic("Invalid ID: \(id) transaction not found in manager at address \(address)")
    return txData
}