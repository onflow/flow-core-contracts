import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction uses a staking admin capability
// to pay rewards, end the staking auction, and end the epoch.
//
// It combines the pay_rewards, end_staking and move_tokens transactions
// which ends the staking auction, which refunds nodes with insufficient stake
// and moves tokens between buckets
// It also sets a new token payout for the next epoch

transaction(ids: [String], newPayout: UFix64) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        let adminCapability = acct.copy<Capability>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not get capability from account storage")

        // borrow a reference to the admin object
        self.adminRef = adminCapability.borrow<&FlowIDTableStaking.Admin>()
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {

        let rewardsArray = self.adminRef.calculateRewards()
        self.adminRef.payRewards(rewardsArray)

        self.adminRef.setEpochTokenPayout(newPayout)

        self.adminRef.setApprovedList(ids)

        self.adminRef.endStakingAuction()

        self.adminRef.moveTokens()
    }
}
