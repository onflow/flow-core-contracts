import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"
import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(amount: UFix64) {

    let holderRef: &LockedTokens.TokenHolder
    let vaultRef: &FlowToken.Vault

    prepare(acct: auth(BorrowValue) &Account) {
        self.holderRef = acct.storage.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow a reference to TokenHolder")

        self.vaultRef = acct.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow flow token vault ref")
    }

    execute {
        self.holderRef.deposit(from: <-self.vaultRef.withdraw(amount: amount))
    }
}
