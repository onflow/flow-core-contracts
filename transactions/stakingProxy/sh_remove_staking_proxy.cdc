import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(nodeID: String) {

    prepare(acct: AuthAccount) {
        let proxyHolder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(from: paStakingProxy.NodeOperatorCapabilityStoragePathth)

        proxyHolder.removeStakingProxy(nodeID: nodeID)
    }
}
