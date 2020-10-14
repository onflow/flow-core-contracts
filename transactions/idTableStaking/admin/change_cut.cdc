import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction changes the flow token reward cut that nodes take from delegators

transaction(newCutPercentage: UFix64) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        self.adminRef.setCutPercentage(newCutPercentage)
    }
}