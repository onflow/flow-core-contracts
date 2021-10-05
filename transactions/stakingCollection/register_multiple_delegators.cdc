import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Registers multiple delegators in the staking collection resource
/// for the specified nodeIDs and amount of tokens to commit

transaction(ids: [String], amounts: [UFix64]) {
    
    let stakingCollectionRef: &FlowStakingCollection.StakingCollection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        var i = 0
        for id in ids {
            self.stakingCollectionRef.registerDelegator(nodeID: id, amount: amounts[i])    

            i = i + 1
        }
    }
}
