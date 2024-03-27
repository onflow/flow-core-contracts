import FlowServiceAccount from "FlowServiceAccount"

// This transaction adds a new account crerator
transaction(accountCreator: Address) {

	let serviceAccountAdmin: &FlowServiceAccount.Administrator

	prepare(signer: auth(BorrowValue) &Account) {
		// Borrow reference to FlowServiceAccount Administrator resource.
		//
		self.serviceAccountAdmin = signer.storage.borrow<&FlowServiceAccount.Administrator>(from: /storage/flowServiceAdmin)
			?? panic("Unable to borrow reference to administrator resource")
	}
	execute {
		self.serviceAccountAdmin.addAccountCreator(accountCreator)
	}
}