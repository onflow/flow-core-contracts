import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(nodeID: String) {

    prepare(account: AuthAccount) {
        let proxyHolder = account.borrow<&StakingProxy.NodeStakerProxyHolder>(from: paStakingProxy.NodeOperatorCapabilityStoragePathth)

        proxyHolder.removeStakingProxy(nodeID: nodeID)
    }
}
