import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// Transfers a NodeDelegator object from an authorizers accoount
// and adds the NodeDelegator to another accounts Staking Collection
// identified by the to Address.

transaction(nodeID: String, delegatorID: UInt32, to: Address) {
    let fromStakingCollectionRef: &FlowStakingCollection.StakingCollection
    let toStakingCollectionCap: &FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}

    prepare(account: AuthAccount) {
        // The account to transfer the NodeDelegator object to must have a valid Staking Collection in order to receive the NodeDelegator.
        if (!FlowStakingCollection.doesAccountHaveStakingCollection(address: to)) {
            panic("Destination account must have a Staking Collection set up.")
        }

        // Get a reference to the authorizers StakingCollection
        self.fromStakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")

        // Get the PublicAccount of the account to transfer the NodeDelegator to. 
        let toAccount = getAccount(to)

        // Borrow a capability to the public methods available on the receivers StakingCollection.
        self.toStakingCollectionCap = toAccount.getCapability<&FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}>(FlowStakingCollection.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        // Remove the NodeDelegator from the authorizers StakingCollection.
        let nodeDelegator <- self.fromStakingCollectionRef.removeDelegator(nodeID: nodeID, delegatorID: delegatorID)

        // Deposit the NodeDelegator to the receivers StakingCollection.
        self.toStakingCollectionCap.addDelegatorObject(<- nodeDelegator!)
    }
}