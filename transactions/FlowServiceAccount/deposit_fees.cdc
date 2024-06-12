import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"
import FlowFees from "FlowFees"

// Deposit tokens to the FlowFees Vault
// only for testing

transaction(amount: UFix64) {

    // The Vault resource that holds the tokens that are being transferred
    let sentVault: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {

        // Get a reference to the signer's stored vault
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw tokens from the signer's stored vault
        self.sentVault <- vaultRef.withdraw(amount: amount)
    }

    execute {
        // Deposit the withdrawn tokens in the FlowFees vault
        FlowFees.deposit(from: <-self.sentVault)
    }
}