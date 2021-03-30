import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

transaction(nodeID: String) {
    
    let stakingCollectionRef: &FlowStakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.Collection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.unstakeAll(nodeID: nodeID)
    }
}
