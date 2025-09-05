import "TestFlowCallbackQueue"
import "FlowCallbackScheduler"


transaction {
    prepare(serviceAccount: auth(BorrowValue) &Account) {
        let scheduler = serviceAccount.storage.borrow<auth(FlowCallbackScheduler.Process) &FlowCallbackScheduler.SharedScheduler>(from: FlowCallbackScheduler.storagePath)
            ?? panic("Could not borrow FlowCallbackScheduler")

        let pendingQueue = scheduler.pendingQueue()
        let actualIDs: [UInt64] = []
        
        for callback in pendingQueue {
            actualIDs.append(callback.id)
        }
        
        TestFlowCallbackQueue.assertPendingQueue(actualIDs: actualIDs)
    }
}

