import LockedTokens from "LockedTokens"
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"

transaction(amount: UFix64) {

    let holderRef: auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder
    let vaultRef: &FlowToken.Vault

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")

        self.vaultRef = account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FlowToken value")
    }

    execute {
        let stakerProxy = self.holderRef.borrowStaker()

        stakerProxy.withdrawRewardedTokens(amount: amount)
        self.vaultRef.deposit(from: <-self.holderRef.withdraw(amount: amount))
    }
}
