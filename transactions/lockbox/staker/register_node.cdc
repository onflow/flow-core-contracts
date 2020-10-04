import Lockbox from 0xf3fcd2c1a78f5eee
import StakingProxy from 0x179b6b1cb6755e31

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, amount: UFix64) {

    let holderRef: &Lockbox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&Lockbox.TokenHolder>(from: Lockbox.TokenHolderStoragePath)
    }

    execute {
        let nodeInfo = StakingProxy.NodeInfo(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)

        self.holderRef.createNodeStaker(nodeInfo: nodeInfo, amount: amount)
    }
}