import LockedTokens from 0xLOCKEDTOKENADDRESS
import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(address: Address, id: String, amount: UFix64) {

    let holderRef: &LockedTokens.TokenHolder

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")
    }

    execute {
        let nodeOperatorRef = getAccount(address).capabilities
            .borrow<&StakingProxy.NodeStakerProxyHolder{StakingProxy.NodeStakerProxyHolderPublic}>(
                StakingProxy.NodeOperatorCapabilityPublicPath
            )
            ?? panic("Could not borrow node operator public capability")

        let nodeInfo = nodeOperatorRef.getNodeInfo(nodeID: id)
            ?? panic("Couldn't get info for nodeID=".concat(id))

        self.holderRef.createNodeStaker(nodeInfo: nodeInfo, amount: amount)

        let nodeStakerProxy = self.holderRef.borrowStaker()

        nodeOperatorRef.addStakingProxy(nodeID: nodeInfo.id, proxy: nodeStakerProxy)
    }
}
