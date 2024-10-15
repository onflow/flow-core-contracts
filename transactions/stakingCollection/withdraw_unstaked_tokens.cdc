import FlowStakingCollection from "FlowStakingCollection"

/// Request to withdraw unstaked tokens for the specified node or delegator in the staking collection
/// The tokens are automatically deposited to the unlocked account vault first,
/// And then any locked tokens are deposited into the locked account vault if it is there

transaction(nodeID: String, delegatorID: UInt32?, amount: UFix64) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic(FlowStakingCollection.getCollectionMissingError(nil))
    }

    execute {
        self.stakingCollectionRef.withdrawUnstakedTokens(nodeID: nodeID, delegatorID: delegatorID, amount: amount)
    }
}
