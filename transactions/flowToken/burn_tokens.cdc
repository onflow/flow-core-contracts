// This transaction is a template for a transaction that
// could be used by the admin account to burn tokens
// from their stored Vault
//
// The burning amount would be a parameter to the transaction

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

transaction(amount: UFix64) {

    // Vault resource that holds the tokens that are being burned
    let vault: @FungibleToken.Vault

    let admin: &FlowToken.Administrator

    prepare(signer: AuthAccount) {

        // Withdraw tokens from the admin vault in storage
        self.vault <- signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)!
            .withdraw(amount: amount)

        // Create a reference to the admin admin resource in storage
        self.admin = signer.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
            ?? panic("Could not borrow a reference to the admin resource")
    }

    execute {
        let burner <- self.admin.createNewBurner()
        
        burner.burnTokens(from: <-self.vault)

        destroy burner
    }
}
 