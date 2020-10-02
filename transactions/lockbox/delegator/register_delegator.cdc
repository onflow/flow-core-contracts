// import Lockbox from 0
// import StakingProxy from 0

transaction(id: String, amount: UFix64) {

    let holderRef: &LockBox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockBox.TokenHolder>(from: LockBox.TokenHolderStoragePath)
    }

    execute {
        self.holderRef.createNodeDelagtor(nodeID: nodeInfo)
    }
}