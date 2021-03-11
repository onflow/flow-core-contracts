import FlowFees from 0xFLOWFEES

// This transaction changes the flow fees parameters
transaction(inclusionFeeFactor: UFix64?, computationFeeFactor: UFix64?) {
    
    let adminRef: &FlowFees.Administrator

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowFees.Administrator>(from: /storage/flowFeesAdmin)
            ?? panic("Could not borrow reference to fees admin")
    }

    execute {
        if inclusionFeeFactor != nil {
            self.adminRef.setInclusionFeeFactor(inclusionFeeFactor!)
        }
        if computationFeeFactor != nil {
            self.adminRef.setComputationFeeFactor(computationFeeFactor!)
        }
    }
}