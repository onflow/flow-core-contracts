import "FlowIDTableStaking"

// This transaction pays rewards to all the staked nodes

transaction {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the admin object
        self.adminRef = acct.storage.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        let summary = self.adminRef.calculateRewards()
        self.adminRef.payRewards(forEpochCounter: 1, rewardsSummary: summary)
    }
}