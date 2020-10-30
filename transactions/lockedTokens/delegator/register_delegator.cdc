import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(id: String, amount: UFix64) {

    let holderRef: &LockedTokens.TokenHolder

    prepare(account: AuthAccount) {
        self.holderRef = account.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath) 
            ?? panic("TokenHolder is not saved at specified path")
    }

    execute {
        self.holderRef.createNodeDelegator(nodeID: id)

        let delegatorProxy = self.holderRef.borrowDelegator()

        delegatorProxy.delegateNewTokens(amount: amount)
    }
}
