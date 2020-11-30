import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction changes the staking minumums for node operators

transaction(newMinimums: [UFix64]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        let minimums: {UInt8: UFix64} = {}
        var i: UInt8 = 1
        for min in newMinimums {
            minimums[i] = min
            i = i + UInt8(1)
        }

        self.adminRef.setMinimumStakeRequirements(minimums)
    }
}