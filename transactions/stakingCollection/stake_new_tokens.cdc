import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

transaction(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
    
    let stakingCollectionRef: &FlowStakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.Collection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.stakeNewTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount)
    }
}
