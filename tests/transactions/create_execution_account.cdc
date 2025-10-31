import "FlowTransactionScheduler"

transaction {
	prepare(serviceAccount: auth(Capabilities, Storage) &Account) {
		let newAccount = Account(payer: serviceAccount)

        // Issue an `Execute`-entitled capability for `@FlowTransactionScheduler.SharedScheduler`
        let capability = serviceAccount.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &FlowTransactionScheduler.SharedScheduler>(/storage/sharedScheduler)

        // Store the capability in the new account
        newAccount.storage.save(capability, to: /storage/executeScheduledTransactionsCapability)

        // Create a fully entitled `&Account` capability for the new account
        let accountCapability = newAccount.capabilities.account.issue<auth(Storage, Contracts, Keys, Inbox, Capabilities) &Account>()
        
        // Store the Account object in the storage of the service account
        serviceAccount.storage.save(accountCapability, to: /storage/executeScheduledTransactionsAccount)
	}
}