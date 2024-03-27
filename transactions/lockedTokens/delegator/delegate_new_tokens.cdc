import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"
import LockedTokens from "LockedTokens"

transaction(amount: UFix64) {

    let holderRef: auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder

    let vaultRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")

        self.vaultRef = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow flow token vault reference")
    }

    execute {
        let stakerProxy = self.holderRef.borrowDelegator()

        let lockedBalance = self.holderRef.getLockedAccountBalance()

        if amount <= lockedBalance {

            stakerProxy.delegateNewTokens(amount: amount)

        } else if ((amount - lockedBalance) <= self.vaultRef.balance) {

            self.holderRef.deposit(from: <-self.vaultRef.withdraw(amount: amount - lockedBalance))

            stakerProxy.delegateNewTokens(amount: amount)
        } else {
            panic("Not enough tokens to stake!")
        }
    }
}
