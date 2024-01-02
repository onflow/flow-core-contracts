import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction() {

    prepare(nodeOperator: auth(SaveValue, Capabilities) &Account) {
        let proxyHolder <- StakingProxy.createProxyHolder()

        nodeOperator.storage.save(<-proxyHolder, to: StakingProxy.NodeOperatorCapabilityStoragePath)

        let nodeOperatorCap = nodeOperator.capabilities.storage.issue<&StakingProxy.NodeStakerProxyHolder>(
            StakingProxy.NodeOperatorCapabilityStoragePath
        )

        nodeOperator.capabilities.publish(
            nodeOperatorCap,
            at: StakingProxy.NodeOperatorCapabilityPublicPath
        )
    }
}
