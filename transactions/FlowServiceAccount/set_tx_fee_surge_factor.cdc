import FlowFees from 0xFLOWFEESADDRESS

// This transaction sets the FlowFees parameters
transaction(surgeFactor: UFix64) {
	let flowFeesAccountAdmin: &FlowFees.Administrator

	prepare(signer: AuthAccount) {
		self.flowFeesAccountAdmin = signer.borrow<&FlowFees.Administrator>(from: /storage/flowFeesAdmin)
			?? panic("Unable to borrow reference to administrator resource")
	}
	execute {
		self.flowFeesAccountAdmin.setFeeSurgeFactor(surgeFactor: surgeFactor)
	}
}