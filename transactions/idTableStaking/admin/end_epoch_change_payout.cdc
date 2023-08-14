import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowEpoch from 0xEPOCHADDRESS
// This transaction effectively ends the epoch and starts a new one.
//
// It combines the end_staking and move_tokens transactions
// which ends the staking auction, which refunds nodes with insufficient stake
// and moves tokens between buckets

transaction(ids: {String: Bool}, newPayout: UFix64) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {

        self.adminRef.setEpochTokenPayout(newPayout)

        self.adminRef.setApprovedList(ids)

        self.adminRef.endStakingAuction()

        self.adminRef.moveTokens(FlowEpoch.currentEpochCounter)
    }
}
