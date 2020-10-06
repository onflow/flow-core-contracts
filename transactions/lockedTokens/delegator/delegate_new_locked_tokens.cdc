import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import LockedTokens from 0xf3fcd2c1a78f5eee

transaction(amount: UFix64) {

    let holderRef: &LockedTokens.TokenHolder

    let vaultRef: &FlowToken.Vault

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")

        self.vaultRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
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