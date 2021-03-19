import StakingCollection from 0xSTAKINGCOLLECTION

transaction(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
    
    let stakingCollectionRef: &StakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&StakingCollection.Collection>(from: StakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.stakeRewardedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount)
    }
}
