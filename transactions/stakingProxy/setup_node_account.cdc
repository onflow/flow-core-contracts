import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction() {

    prepare(nodeOperator: auth(SaveValue) &Account) {
        let proxyHolder <- StakingProxy.createProxyHolder()

        nodeOperator.storage.save(<-proxyHolder, to: StakingProxy.NodeOperatorCapabilityStoragePath)

        let nodeOperatorCap = nodeOperator.capabilities.storage.issue<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(
            StakingProxy.NodeOperatorCapabilityStoragePath
        )

        nodeOperator.capabilities.publish(
            StakingProxy.NodeOperatorCapabilityPublicPath,
            at: StakingProxy.NodeOperatorCapabilityStoragePath
        )
    }
}
