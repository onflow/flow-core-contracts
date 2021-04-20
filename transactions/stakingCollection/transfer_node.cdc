import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// Transfers a NodeStaker object from an authorizers accoount
// and adds the NodeStaker to another accounts Staking Collection
// identified by the to Address.

transaction(nodeID: String, to: Address) {
    let fromStakingCollectionRef: &FlowStakingCollection.StakingCollection
    let toStakingCollectionCap: &FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}

    prepare(account: AuthAccount) {
        if (!FlowStakingCollection.doesAccountHaveStakingCollection(address: to)) {
            panic("Destination account must have a Staking Collection set up.")
        }

        self.fromStakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")

        let toAccount = getAccount(to)

        self.toStakingCollectionCap = toAccount.getCapability<&FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}>(FlowStakingCollection.StakingCollectionPublicPath).borrow()
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        let nodeStaker <- self.fromStakingCollectionRef.removeNode(nodeID: nodeID)

        self.toStakingCollectionCap.addNodeObject(<- nodeStaker!)
    }
}
