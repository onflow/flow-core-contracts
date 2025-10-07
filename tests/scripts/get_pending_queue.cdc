import "FlowTransactionScheduler"

access(all) fun main(): [UInt64] {

    let schedulerAccount = getAuthAccount<auth(BorrowValue) &Account>(0x0000000000000007)

    let scheduler = schedulerAccount.storage.borrow<auth(FlowTransactionScheduler.Process) &FlowTransactionScheduler.SharedScheduler>(from: FlowTransactionScheduler.storagePath)
            ?? panic("Could not borrow FlowTransactionScheduler")

    let pendingQueue = scheduler.pendingQueue()

    var ids: [UInt64] = []
    for tx in pendingQueue {
        ids.append(tx.id)
    }

    return ids
}
