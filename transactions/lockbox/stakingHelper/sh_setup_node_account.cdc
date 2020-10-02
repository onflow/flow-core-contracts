// import StakingProxy from 0x

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String) {

    prepare(acct: AuthAccount) {
        let proxyHolder = StakingProxy.createProxyHolder()

        acct.save(<-proxyHolder, to: StakingProxy.NodeOperatorCapabilityStoragePath)

        acct.link<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(StakingProxy.NodeOperatorCapabilityPublicPath, target: StakingProxy.NodeOperatorCapabilityStoragePath)
    }

}