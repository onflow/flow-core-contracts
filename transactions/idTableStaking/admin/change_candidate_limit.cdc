import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

/// This transaction changes the limit of new nodes that can be candidates
/// for the next epoch

transaction(newCandidateNodeLimit: Int) {

    /// Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        self.adminRef.setCandidateNodeLimit(newCandidateNodeLimit)
    }
}