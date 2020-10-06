import StakingProxy from 0x179b6b1cb6755e31

// ID: NO.01 
// Authorizer: Node Operator
// 
transaction() {

    prepare(nodeOperator: AuthAccount) {
        let proxyHolder <- StakingProxy.createProxyHolder()

        nodeOperator.save(<-proxyHolder, to: StakingProxy.NodeOperatorCapabilityStoragePath)

        nodeOperator.link<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(StakingProxy.NodeOperatorCapabilityPublicPath, target: StakingProxy.NodeOperatorCapabilityStoragePath)
    }
}
