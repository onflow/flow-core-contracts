import FlowStakingCollection from "FlowStakingCollection"

/// Request to withdraw tokens from the machine account
/// The tokens are automatically deposited to the unlocked account vault

transaction(nodeID: String, amount: UFix64) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic(FlowStakingCollection.getCollectionMissingError(nil))
    }

    execute {
        self.stakingCollectionRef.withdrawFromMachineAccount(nodeID: nodeID, amount: amount)
    }
}
