import FlowStakingCollection from "FlowStakingCollection"

/// Registers multiple delegators in the staking collection resource
/// for the specified nodeIDs and amount of tokens to commit

transaction(ids: [String], amounts: [UFix64]) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("The signer does not store a Staking Collection object at the path "
                    .concat(FlowStakingCollection.StakingCollectionStoragePath.toString())
                    .concat(". The signer must initialize their account with this object first!"))
    }

    execute {
        var i = 0
        for id in ids {
            self.stakingCollectionRef.registerDelegator(nodeID: id, amount: amounts[i])    

            i = i + 1
        }
    }
}
