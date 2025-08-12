import "FlowCallbackScheduler"

// Execute a scheduled callback by the FlowCallbackScheduler contract.
// This will be called by the FVM and the callback will be executed by their ID.
transaction(id: UInt64) {
    prepare(serviceAccount: auth(BorrowValue) &Account) {
        let scheduler = serviceAccount.storage.borrow<&FlowCallbackScheduler.SharedScheduler>(from: FlowCallbackScheduler.schedulerStoragePath)
            ?? panic("Could not borrow FlowCallbackScheduler")

        scheduler.executeCallback(id: id)
    }
}