import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction(recipient: Address, amount: UFix64) {
    let tokenAdmin: &FlowArcadeToken.Administrator
    let tokenReceiver: &FlowArcadeToken.Vault{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        self.tokenAdmin = signer
        .borrow<&FlowArcadeToken.Administrator>(from: FlowArcadeToken.AdminStoragePath) 
        ?? panic("Signer is not the token admin")

        self.tokenReceiver = getAccount(recipient)
        .getCapability(FlowArcadeToken.ReceiverPublicPath)!
        .borrow<&FlowArcadeToken.Vault{FungibleToken.Receiver}>()
        ?? panic("Unable to borrow receiver reference")
    }

    execute {
        let minter <- self.tokenAdmin.createNewMinter(allowedAmount: amount)
        let mintedVault <- minter.mintTokens(amount: amount)

        self.tokenReceiver.deposit(from: <-mintedVault)

        destroy minter
    }
}