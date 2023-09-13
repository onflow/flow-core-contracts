import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(nodeID: String) {

    prepare(account: auth(BorrowValue) &Account) {
        let proxyHolder = account.storage.borrow<&StakingProxy.NodeStakerProxyHolder>(from: StakingProxy.NodeOperatorCapabilityStoragePath)

        proxyHolder.removeNodeInfo(nodeID: nodeID)
    }
}
