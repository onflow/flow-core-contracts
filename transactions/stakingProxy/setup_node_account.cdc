import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction() {

    prepare(nodeOperator: AuthAccount) {
        let proxyHolder <- StakingProxy.createProxyHolder()

        nodeOperator.save(<-proxyHolder, to: StakingProxy.NodeOperatorCapabilityStoragePath)

        nodeOperator.link<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(
            StakingProxy.NodeOperatorCapabilityPublicPath,
            target: StakingProxy.NodeOperatorCapabilityStoragePath
        )
    }
}
