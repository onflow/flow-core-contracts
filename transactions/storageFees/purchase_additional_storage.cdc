import StorageFees from 0xSTORAGEFEES

transaction(forAddress: Address, storageAmount: UInt64) {
    // The Vault resource that holds the tokens that will be used to pay for storage
    let paymentVault: @FungibleToken.Vault
    // Storage capacity amount that will be added to the account
    let storage: UInt64

    prepare(account: AuthAccount) {
        // Round up storage to the closest unit
        self.storage = StorageFees.roundUpStorageCapacity(storageAmount)
        // Get the cost of this storage capacity
        let flowAmount = StorageFees.getFlowCost(self.storage)

        // Get a reference to the signer's stored vault
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw tokens from the signer's stored vault
        self.paymentVault <- vaultRef.withdraw(amount: flowAmount)
    }

    execute {
        // Purchase additional storage for account
        StorageFees.addStorageCapacity(to: forAddress, storageAmount: self.storage, paymentVault: self.paymentVault)
    }
}
