import StakingProxy from "StakingProxy"

access(all) fun main(account: Address, nodeID: String): StakingProxy.NodeInfo {

    let proxyRef = getAccount(account)
        .capabilities.borrow<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(
            StakingProxy.NodeOperatorCapabilityPublicPath
        )
        ?? panic("Could not borrow public reference to staking proxy")

    return proxyRef.getNodeInfo(nodeID: nodeID)!
}
