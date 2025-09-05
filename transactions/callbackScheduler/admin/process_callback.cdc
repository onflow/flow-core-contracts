import "FlowCallbackScheduler"

// Process scheduled callbacks by the FlowCallbackScheduler contract.
// This will be called by the FVM and all scheduled callbacks that should be 
// executed will be processed. An event for each will be emitted.
transaction {
    prepare(serviceAccount: auth(BorrowValue) &Account) {
        let scheduler = serviceAccount.storage.borrow<auth(FlowCallbackScheduler.Process) &FlowCallbackScheduler.SharedScheduler>(from: FlowCallbackScheduler.storagePath)
            ?? panic("Could not borrow FlowCallbackScheduler")

        scheduler.process()
    }
}