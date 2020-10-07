// This transaction is a template for a transaction
// to add a Vault resource to their account
// so that they can use the FlowArcadeToken

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction {

    prepare(signer: AuthAccount) {

        // If the account is already set up that's not a problem, but we don't want to replace it
        if(signer.borrow<&FlowArcadeToken.Vault>(from: /storage/flowArcadeTokenVault) != nil) {
            return
        }
        
        // Create a new FlowArcadeToken Vault and put it in storage
        signer.save(<-FlowArcadeToken.createEmptyVault(), to: /storage/flowArcadeTokenVault)

        // Create a public capability to the Vault that only exposes
        // the deposit function through the Receiver interface
        signer.link<&FlowArcadeToken.Vault{FungibleToken.Receiver}>(
            /public/flowArcadeTokenReceiver,
            target: /storage/flowArcadeTokenVault
        )

        // Create a public capability to the Vault that only exposes
        // the balance field through the Balance interface
        signer.link<&FlowArcadeToken.Vault{FungibleToken.Balance}>(
            /public/flowArcadeTokenBalance,
            target: /storage/flowArcadeTokenVault
        )
    }
}
