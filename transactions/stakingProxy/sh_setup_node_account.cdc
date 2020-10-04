import StakingProxy from 0x179b6b1cb6755e31

transaction() {

    prepare(acct: AuthAccount) {
        let proxyHolder <- StakingProxy.createProxyHolder()

        acct.save(<-proxyHolder, to: StakingProxy.NodeOperatorCapabilityStoragePath)

        acct.link<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(StakingProxy.NodeOperatorCapabilityPublicPath, target: StakingProxy.NodeOperatorCapabilityStoragePath)
    }

}