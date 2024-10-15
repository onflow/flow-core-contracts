// This transaction is a template for a transaction that
// could be used by the admin account to burn tokens
// from their stored Vault
//
// The burning amount would be a parameter to the transaction

import "FungibleToken"
import "FlowToken"
import "Burner"

transaction(amount: UFix64) {

    // Vault resource that holds the tokens that are being burned
    let vault: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {

        // Withdraw tokens from the admin vault in storage
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("The signer does not store a FlowToken Vault object at the path "
                    .concat("/storage/flowTokenVault. ")
                    .concat("The signer must initialize their account with this vault first!"))

        self.vault <- vaultRef.withdraw(amount: amount)
    }

    execute {
        Burner.burn(<-self.vault)
    }
}
 