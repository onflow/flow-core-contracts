import StakingCollection from 0xSTAKINGCOLLECTION
import StakingProxy from 0xSTAKINGPROXY

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, amount: UFix64) {
    
    let stakingCollectionRef: &StakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&StakingCollection.Collection>(from: StakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        let nodeInfo = StakingProxy.NodeInfo(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey)

        stakingCollectionRef.registerNode(nodeInfo: nodeInfo, amount: amount)
        
    }
}
