import "FlowCallbackScheduler"

access(all) fun main(): [UInt64] {

    let schedulerAccount = getAuthAccount<auth(BorrowValue) &Account>(0x0000000000000001)

    let scheduler = schedulerAccount.storage.borrow<auth(FlowCallbackScheduler.Process) &FlowCallbackScheduler.SharedScheduler>(from: FlowCallbackScheduler.storagePath)
            ?? panic("Could not borrow FlowCallbackScheduler")

    let pendingQueue = scheduler.pendingQueue()

    var ids: [UInt64] = []
    for callback in pendingQueue {
        ids.append(callback.id)
    }

    return ids
}
