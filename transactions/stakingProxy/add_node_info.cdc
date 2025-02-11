import "StakingProxy"

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String) {

    prepare(account: auth(BorrowValue) &Account) {
        let proxyHolder = account.storage.borrow<&StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow reference to staking proxy holder")

        let nodeInfo = StakingProxy.NodeInfo(nodeID: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)

        proxyHolder.addNodeInfo(nodeInfo: nodeInfo)
    }
}
