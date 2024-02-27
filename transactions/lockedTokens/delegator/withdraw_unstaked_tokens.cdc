import LockedTokens from "LockedTokens"
import FungibleToken from "FungibleToken"

transaction(amount: UFix64) {
    let nodeDelegatorProxy: LockedTokens.LockedNodeDelegatorProxy

    prepare(account: auth(BorrowValue) &Account) {
        let holderRef = account.storage.borrow<auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("TokenHolder is not saved at specified path")
        
        self.nodeDelegatorProxy = holderRef.borrowDelegator()
    }

    execute {
        self.nodeDelegatorProxy.withdrawUnstakedTokens(amount: amount)
    }
}
