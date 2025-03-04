import "FlowToken"
import "LockedTokens"
import "FlowIDTableStaking"
import "FungibleToken"

transaction(id: String, amount: UFix64) {

    let holderRef: auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder

    let vaultRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("TokenHolder is not saved at specified path")

        self.vaultRef = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow flow token vault reference")
    }

    execute {
        let lockedBalance = self.holderRef.getLockedAccountBalance()

        if amount <= lockedBalance {

            self.holderRef.createNodeDelegator(nodeID: id)

            let stakerProxy = self.holderRef.borrowDelegator()

            stakerProxy.delegateNewTokens(amount: amount - FlowIDTableStaking.getDelegatorMinimumStakeRequirement())

        } else if ((amount - lockedBalance) <= self.vaultRef.balance) {

            self.holderRef.deposit(from: <-self.vaultRef.withdraw(amount: amount - lockedBalance))

            self.holderRef.createNodeDelegator(nodeID: id)

            let stakerProxy = self.holderRef.borrowDelegator()

            stakerProxy.delegateNewTokens(amount: amount - FlowIDTableStaking.getDelegatorMinimumStakeRequirement())

        } else {
            panic("Not enough tokens to stake!")
        }
    }
}
