import FlowStakingCollection from "FlowStakingCollection"

// Transfers a NodeStaker object from an authorizers account
// and adds the NodeStaker to another accounts Staking Collection
// identified by the to Address.

transaction(nodeID: String, to: Address) {
    let fromStakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection
    let toStakingCollectionCap: &FlowStakingCollection.StakingCollection

    prepare(account: auth(BorrowValue) &Account) {
        // The account to transfer the NodeStaker object to must have a valid Staking Collection in order to receive the NodeStaker.
        if (!FlowStakingCollection.doesAccountHaveStakingCollection(address: to)) {
            panic("The desination account does not store a Staking Collection object at the path "
                .concat(FlowStakingCollection.StakingCollectionStoragePath.toString())
                .concat(". The destination account must initialize their account with this object first!"))
        }

        // Get a reference to the authorizers StakingCollection
        self.fromStakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("The signer does not store a Staking Collection object at the path "
                    .concat(FlowStakingCollection.StakingCollectionStoragePath.toString())
                    .concat(". The signer must initialize their account with this object first!"))

        // Get the PublicAccount of the account to transfer the NodeStaker to. 
        let toAccount = getAccount(to)

        // Borrow a capability to the public methods available on the receivers StakingCollection.
        self.toStakingCollectionCap = toAccount.capabilities
            .borrow<&FlowStakingCollection.StakingCollection>(FlowStakingCollection.StakingCollectionPublicPath)
            ?? panic("Could not borrow a reference to a StakingCollection in the receiver's account")

        let machineAccountInfo = self.fromStakingCollectionRef.getMachineAccounts()[nodeID]
            ?? panic("Could not get machine account info from the signer's account for the node ID "
                    .concat(nodeID).concat(". Make sure that the node has configured a machine account ")
                    .concat("and has it registered in the staking collection."))

        // Remove the NodeStaker from the authorizers StakingCollection.
        let nodeStaker <- self.fromStakingCollectionRef.removeNode(nodeID: nodeID)

        // Deposit the NodeStaker to the receivers StakingCollection.
        self.toStakingCollectionCap.addNodeObject(<- nodeStaker!, machineAccountInfo: machineAccountInfo)
    }
}