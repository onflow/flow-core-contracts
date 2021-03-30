import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import StakingProxy from 0xSTAKINGPROXY

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, amount: UFix64) {
    
    let stakingCollectionRef: &FlowStakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.Collection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        let nodeInfo = StakingProxy.NodeInfo(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)

        stakingCollectionRef.registerNode(nodeInfo: nodeInfo, amount: amount)
        
    }
}
