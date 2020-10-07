import StakingProxy from 0xTOKENPROXYADDRESS

transaction(nodeID: String) {

    prepare(acct: AuthAccount) {
        let proxyHolder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(from: paStakingProxy.NodeOperatorCapabilityStoragePathth)

        proxyHolder.removeNodeInfo(nodeID: nodeID)
    }
}
