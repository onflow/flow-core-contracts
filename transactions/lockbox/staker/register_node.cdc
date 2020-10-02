// import Lockbox from 0
// import StakingProxy from 0

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, amount: UFix64) {

    let holderRef: &LockBox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockBox.TokenHolder>(from: LockBox.TokenHolderStoragePath)
    }

    execute {
        let nodeInfo = StakingProxy.NodeInfo(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)

        self.holderRef.createNodeStaker(nodeInfo: nodeInfo, amount: amount)
    }
}