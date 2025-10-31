import "FlowTransactionScheduler"

// Execute a scheduled transaction by the FlowTransactionScheduler contract.
// This will be called by the FVM and the transaction will be executed by their ID.
transaction(id: UInt64) {
    prepare(signer: auth(CopyValue) &Account) {

        let childAccount = signer.storage.copy<Capability<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>>(from: /storage/executeScheduledTransactionsAccount)
            ?? panic("Could not find Execute Scheduled Transactions Account in storage")

        let childAccountRef = childAccount.borrow()
            ?? panic("Could not borrow Execute Scheduled Transactions Account reference")

        let scheduler = childAccountRef.storage.copy<Capability<auth(FlowTransactionScheduler.Execute) &FlowTransactionScheduler.SharedScheduler>>(from: /storage/executeScheduledTransactionsCapability)
            ?? panic("Could not find Execute Scheduled Transactions Capability in storage")

        let schedulerRef = scheduler.borrow()
            ?? panic("Could not borrow FlowTransactionScheduler SharedScheduler reference")

        schedulerRef.executeTransaction(id: id)
    }
}