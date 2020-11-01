import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction(recipient: Address, amount: UFix64) {
    let minterProxy: &FlowArcadeToken.MinterProxy
    let tokenReceiver: &FlowArcadeToken.Vault{FungibleToken.Receiver}

    prepare(signer: AuthAccount) {
        self.minterProxy = signer
        .borrow<&FlowArcadeToken.MinterProxy>(from: FlowArcadeToken.MinterProxyStoragePath)
        ?? panic("Signer cannot get MinterProxy")

        self.tokenReceiver = getAccount(recipient)
        .getCapability(FlowArcadeToken.ReceiverPublicPath)!
        .borrow<&FlowArcadeToken.Vault{FungibleToken.Receiver}>()
        ?? panic("Unable to borrow receiver reference")
    }

    execute {
        let mintedVault <- self.minterProxy.mintTokens(amount: amount)

        self.tokenReceiver.deposit(from: <-mintedVault)
    }
}