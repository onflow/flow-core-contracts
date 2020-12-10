import FlowStorageFees from 0xFLOWSTORAGEFEES

transaction(forAddress: Address, flowAmount: UFix64) {
    // The Vault resource that holds the tokens that will be used to pay for storage
    let paymentVault: @FungibleToken.Vault

    prepare(account: AuthAccount) {
        // Get a reference to the signer's stored vault
        let vaultRef = account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw tokens from the signer's stored vault
        self.paymentVault <- vaultRef.withdraw(amount: flowAmount)
    }

    execute {
        let storageReservationReceiver:  = FlowStorageFees.getStorageReservationReceiver(forAddress)
        storageReservationReceiver.deposit(from: <-paymentVault)
    }
}
