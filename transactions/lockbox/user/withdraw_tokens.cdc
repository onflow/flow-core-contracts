import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79
import Lockbox from 0xf3fcd2c1a78f5eee

transaction(amount: UFix64) {

    let holderRef: &Lockbox.TokenHolder
    let vaultRef: &FlowToken.Vault

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&Lockbox.TokenHolder>(from: Lockbox.TokenHolderStoragePath)
            ?? panic("Could not borrow a reference to TokenHolder")

        self.vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow flow token vault ref")
    }

    execute {
        self.vaultRef.deposit(from: <-self.holderRef.withdraw(amount: amount))
    }
}