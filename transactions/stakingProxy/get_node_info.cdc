import StakingProxy from 0xSTAKINGPROXYADDRESS

pub fun main(account: Address, nodeID: String): StakingProxy.NodeInfo {

    let nodeAccount = getAccount(account)

    let proxyCapability = nodeAccount.getCapability
        <&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>
        (StakingProxy.NodeOperatorCapabilityPublicPath)!

    let proxyRef = proxyCapability.borrow()
        ?? panic("Could not borrow public reference to staking proxy")

    return proxyRef.getNodeInfo(nodeID: nodeID)!
}
