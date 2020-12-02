import StorageFees from 0xSTORAGEFEES

transaction(forAddress: Address) {
    // The Vault resource that holds the tokens that will be used to pay for storage
    let paymentVault: @FungibleToken.Vault
    // signers vault to deposit the remainder of Flow tokens after purchasing storage
    let receiverRef: &{FungibleToken.Receiver}

    prepare(account: AuthAccount) {


        // Get a reference to the signer's stored vault
        let vaultRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw the maximum amount of tokens from the signer's stored vault that the signer is willing to pay for accounts storage.
        self.paymentVault <- vaultRef.withdraw(amount: 10)


        // Get a reference to the signer's Receiver
        self.receiverRef = signer.getCapability(/public/flowTokenReceiver)!.borrow<&{FungibleToken.Receiver}>()
			?? panic("Could not borrow receiver reference to the recipient's Vault")
    }

    execute {
        // Purchase minimum additional storage for account so that it has enough to get through this transaction. 
        // This would be done on the end of a transaction that is adding things to accounts storage
        // in order to guarantee the transaction doesn't fail because the address doesn't have enough storage.
        // On its own this function is not useful.
        let remainder <- StorageFees.purchaseMinimumAditionalRequiredStorageCapacity(for: forAddress, paymentVault: self.paymentVault)
        self.receiverRef.deposit(from: <- remainder)
    }
}