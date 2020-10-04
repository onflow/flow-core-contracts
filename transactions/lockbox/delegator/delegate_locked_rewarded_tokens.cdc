import Lockbox from 0xf3fcd2c1a78f5eee

transaction(amount: UFix64) {
    let nodeDelegatorProxy: Lockbox.LockedNodeDelegatorProxy

    prepare(acct: AuthAccount) {
        let holderRef = acct.borrow<&Lockbox.TokenHolder>(from: Lockbox.TokenHolderStoragePath) 
            ?? panic("TokenHolder is not saved at specified path")
        
        self.nodeDelegatorProxy = self.holderRef.borrowDelegator()
    }

    execute {
        self.nodeDelegatorProxy.delegateRewardedTokens(amount: amount)
    }

}