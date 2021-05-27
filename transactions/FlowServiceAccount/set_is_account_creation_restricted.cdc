import FlowServiceAccount from 0xFLOWSERVICEADDRESS

// This transaction changes `is account ceration restricted` value
transaction(restricted: Bool) {

	let serviceAccountAdmin: &FlowServiceAccount.Administrator

	prepare(signer: AuthAccount) {
		// Borrow reference to FlowServiceAccount Administrator resource.
		//
		self.serviceAccountAdmin = signer.borrow<&FlowServiceAccount.Administrator>(from: /storage/flowServiceAdmin)
			?? panic("Unable to borrow reference to administrator resource")
	}
	execute {
		self.serviceAccountAdmin.setIsAccountCreationRestricted(restricted)
	}
}