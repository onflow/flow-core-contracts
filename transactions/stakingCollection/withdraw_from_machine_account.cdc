import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Request to withdraw tokens from the machine account
/// The tokens are automatically deposited to the unlocked account vault

transaction(nodeID: String, amount: UFix64) {
    
    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow a reference to a StakingCollection in the primary user's account")
    }

    execute {
        self.stakingCollectionRef.withdrawFromMachineAccount(nodeID: nodeID, amount: amount)
    }
}
