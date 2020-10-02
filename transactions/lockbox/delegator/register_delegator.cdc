import Lockbox from 0xf3fcd2c1a78f5eee

transaction(id: String, amount: UFix64) {

    let holderRef: &LockBox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockBox.TokenHolder>(from: LockBox.TokenHolderStoragePath)
    }

    execute {
        self.holderRef.createNodeDelegator(nodeID: nodeInfo)
    }
}