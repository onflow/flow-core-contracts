import StakingProxy from 0x179b6b1cb6755e31

transaction(nodeID: String) {

    let holder: &StakingProxy.NodeStakerProxyHolder
    
    prepare(acct: AuthAccount) {
        self.holder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow acct's NodeStakerProxyHolder")
    }

    execute {
        self.holder.removeNodeInfo(nodeID: nodeID)
    }

}
