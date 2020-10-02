import StakingProxy from 0x179b6b1cb6755e31

transaction(nodeID: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String) {

    let holder
    
    prepare(acct: AuthAccount) {
        self.holder = acct.borrow<&StakingProxy.NodeStakerProxyHolder>(StakingProxy.NodeOperatorCapabilityStoragePath)
            ?? panic("Could not borrow acct's NodeStakerProxyHolder")
    }

    execute {
        let nodeInfo = StakingProxy.NodeInfo(nodeID: nodeID, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)
        self.holder.addNodeInfo(nodeInfo: nodeInfo)
    }

}
