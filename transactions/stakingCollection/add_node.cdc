import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(node: @FlowIDTableStaking.NodeStaker) {
    
    let stakingCollectionRef: &FlowStakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.Collection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.addNodeObject(node: <- node)
    }
}
