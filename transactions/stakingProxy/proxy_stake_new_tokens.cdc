import StakingProxy from 0x179b6b1cb6755e31

transaction(nodeID: String, amount: UFix64) {

    let proxy: &StakingProxy.NodeStakerProxyHolder
    
    prepare(acct: AuthAccount) {
        let holder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow acct's NodeStakerProxyHolder")

        self.proxy = holder.borrowStakingProxy(nodeId: nodeId)
            ?? panic("Could not borrow 's NodeStakerProxy")
    }

    execute {
        self.proxy.stakeNewTokens(amount: amount)
    }

}
