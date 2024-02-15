import FlowFees from "FlowFees"

// This transaction sets the FlowFees parameters
transaction(surgeFactor: UFix64) {
	let flowFeesAccountAdmin: &FlowFees.Administrator

	prepare(signer: auth(BorrowValue) &Account) {
		self.flowFeesAccountAdmin = signer.storage.borrow<&FlowFees.Administrator>(from: /storage/flowFeesAdmin)
			?? panic("Unable to borrow reference to administrator resource")
	}
	execute {
		self.flowFeesAccountAdmin.setFeeSurgeFactor(surgeFactor: surgeFactor)
	}
}