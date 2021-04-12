import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Requests to unstake ALL tokens for the specified node or delegator in the staking collection

transaction(nodeID: String) {
    
    let stakingCollectionRef: &FlowStakingCollection.StakingCollection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        self.stakingCollectionRef.unstakeAll(nodeID: nodeID)
    }
}
