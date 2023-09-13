import StakingProxy from 0xSTAKINGPROXYADDRESS

access(all) fun main(account: Address, nodeID: String): StakingProxy.NodeInfo {

    let proxyCapability = getAccount(account)
        .capabilities.get<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(
            StakingProxy.NodeOperatorCapabilityPublicPath
        )!

    let proxyRef = proxyCapability.borrow()
        ?? panic("Could not borrow public reference to staking proxy")

    return proxyRef.getNodeInfo(nodeID: nodeID)!
}
