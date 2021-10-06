import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction sets the list of nodes who are non operational
// and whose rewards will be withheld

transaction(ids: [String]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        let nodeList: {String: UFix64} = {}
        for id in ids {
            nodeList[id] = 0.0
        }

        self.adminRef.setNonOperationalNodesList(nodeList)
    }
}