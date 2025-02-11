import "FlowIDTableStaking"

// This transaction ends the staking auction, which refunds nodes 
// with insufficient stake

transaction(ids: {String: Bool}) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the admin object
        self.adminRef = acct.storage.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {

        self.adminRef.setApprovedList(ids)

        self.adminRef.endStakingAuction()
    }
}