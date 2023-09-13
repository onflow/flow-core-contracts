
// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the flowToken

import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"

transaction {

    prepare(signer: auth(Storage) &Account) {

        if signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            // Create a new flowToken Vault and put it in storage
            signer.storage.save(<-FlowToken.createEmptyVault(), to: /storage/flowTokenVault)

            // Create a public capability to the Vault that only exposes
            // the deposit function through the Receiver interface
            let vaultCap = signer.capabilities.storage.issue<&FlowToken.Vault{FungibleToken.Receiver}>(
                /storage/flowTokenVault
            )

            signer.capabilities.publish<&FlowToken.Vault{FungibleToken.Receiver}>(
                vaultCap,
                at: /public/flowTokenReceiver,
            )

            // Create a public capability to the Vault that only exposes
            // the balance field through the Balance interface
            let vaultCap = signer.capabilities.storage.issue<&FlowToken.Vault{FungibleToken.Balance}>(
                /storage/flowTokenVault
            )

            signer.capabilities.publish<&FlowToken.Vault{FungibleToken.Receiver}>(
                vaultCap,
                at: /public/flowTokenBalance,
            )
        }
    }
}
 