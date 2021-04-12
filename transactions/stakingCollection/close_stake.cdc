import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// Closes out a staking object in the staking collection
// This does not remove the record from the identity table,
// but it does mean that the account that closes it cannot ever access it again

transaction(nodeID: String, delegatorID: UInt32?) {
    
    let stakingCollectionRef: &FlowStakingCollection.StakingCollection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        self.stakingCollectionRef.closeStake(nodeID: nodeID, delegatorID: delegatorID)
    }
}
