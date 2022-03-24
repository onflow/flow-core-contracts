import FlowFees from 0xFLOWFEESADDRESS

// This transaction sets the FlowFees parameters
transaction(surgeFactor: UFix64, inclusionEffortCost: UFix64, executionEffortCost: UFix64) {
	let flowFeesAccountAdmin: &FlowFees.Administrator

	prepare(signer: AuthAccount) {
		self.flowFeesAccountAdmin = signer.borrow<&FlowFees.Administrator>(from: /storage/flowFeesAdmin)
			?? panic("Unable to borrow reference to administrator resource")
	}
	execute {
		self.flowFeesAccountAdmin.setFeeParameters(surgeFactor: surgeFactor, inclusionEffortCost: inclusionEffortCost, executionEffortCost: executionEffortCost)
	}
}