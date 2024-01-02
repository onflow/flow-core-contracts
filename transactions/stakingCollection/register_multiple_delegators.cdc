import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Registers multiple delegators in the staking collection resource
/// for the specified nodeIDs and amount of tokens to commit

transaction(ids: [String], amounts: [UFix64]) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
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
