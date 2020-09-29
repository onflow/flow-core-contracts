import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction(recipientAddress: Address, amount: UFix64) {
    let tokenMinter: &FlowArcadeToken.Minter
    let tokenReceiver: &{FungibleToken.Receiver}

    prepare(minterAccount: AuthAccount) {
        self.tokenMinter = minterAccount
        .borrow<&FlowArcadeToken.Minter>(from: /storage/flowArcadeTokenMinter) 
        ?? panic("No minter available")

        self.tokenReceiver = getAccount(recipientAddress)
        .getCapability(/public/flowArcadeTokenReceiver)!
        .borrow<&{FungibleToken.Receiver}>()
        ?? panic("Unable to borrow receiver reference")
    }

    execute {
        let mintedVault <- self.tokenMinter.mintTokens(amount: amount)

        self.tokenReceiver.deposit(from: <-mintedVault)
    }
}
