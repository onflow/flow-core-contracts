import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction pays rewards to all the staked nodes

transaction(code: [UInt8]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {

        acct.contracts.update__experimental(name: "FlowIDTableStaking", code: code)

        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        self.adminRef.setClaimed()
    }
}