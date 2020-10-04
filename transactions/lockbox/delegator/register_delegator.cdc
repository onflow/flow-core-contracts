import Lockbox from 0xf3fcd2c1a78f5eee

transaction(id: String, amount: UFix64) {

    let holderRef: &Lockbox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&Lockbox.TokenHolder>(from: Lockbox.TokenHolderStoragePath) 
            ?? panic("TokenHolder is not saved at specified path")
    }

    execute {
        self.holderRef.createNodeDelegator(nodeID: id)

        let delegatorProxy = self.holderRef.borrowDelegator()

        delegatorProxy.delegateNewTokens(amount: amount)
    }
}