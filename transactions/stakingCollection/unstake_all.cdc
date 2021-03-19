import StakingCollection from 0xSTAKINGCOLLECTION

transaction(nodeID: String) {
    
    let stakingCollectionRef: &StakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&StakingCollection.Collection>(from: StakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.unstakeAll(nodeID: nodeID)
    }
}
