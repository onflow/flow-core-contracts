import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Changes the networking address for the specified node

transaction(nodeID: String, newAddress: String) {
    
    let stakingCollectionRef: &FlowStakingCollection.StakingCollection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        self.stakingCollectionRef.updateNetworkingAddress(nodeID: nodeID, newAddress: newAddress)
    }
}
