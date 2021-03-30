import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

transaction(id: String) {
    
    let stakingCollectionRef: &FlowStakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.Collection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.registerDelegator(nodeId: id, amount: amount)       
    }
}
