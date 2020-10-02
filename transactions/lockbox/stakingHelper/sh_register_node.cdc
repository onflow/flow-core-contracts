// import Lockbox from 0
// import StakingProxy from 0

transaction(address: Address, nodeID: String, amount: UFix64) {

    let holderRef: &LockBox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockBox.TokenHolder>(from: LockBox.TokenHolderStoragePath)
    }

    execute {
        let nodeOperatorRef = getAccount(address).getCapability<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>
            (StakingProxy.NodeOperatorCapabilityPublicPath)!.borrow() 
            ?? panic("Could not borrow node operator public capability")

        let nodeInfo = nodeOperatorRef.getNodeInfo(nodeID: nodeID)!

        self.holderRef.createNodeStaker(nodeInfo: nodeInfo, amount: amount)

        let nodeStakerProxy = self.holderRef.borrowStaker()

        nodeOperatorRef.addStakingProxy(nodeID: nodeInfo.id, proxy: nodeStakerProxy)
    }
}