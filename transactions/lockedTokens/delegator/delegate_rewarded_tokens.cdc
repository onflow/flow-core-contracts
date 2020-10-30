import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(amount: UFix64) {
    let nodeDelegatorProxy: LockedTokens.LockedNodeDelegatorProxy

    prepare(account: AuthAccount) {
        let holderRef = account.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath) 
            ?? panic("TokenHolder is not saved at specified path")
        
        self.nodeDelegatorProxy = holderRef.borrowDelegator()
    }

    execute {
        self.nodeDelegatorProxy.delegateRewardedTokens(amount: amount)
    }
}
