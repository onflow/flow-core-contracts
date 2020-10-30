import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String) {

    prepare(account: AuthAccount) {
        let proxyHolder = account.borrow<&StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow reference to staking proxy holder")

        let nodeInfo = StakingProxy.NodeInfo(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)

        proxyHolder.addNodeInfo(nodeInfo: nodeInfo)
    }
}
