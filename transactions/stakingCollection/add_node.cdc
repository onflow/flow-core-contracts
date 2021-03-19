import StakingCollection from 0xSTAKINGCOLLECTION
import StakingProxy from 0xSTAKINGPROXY

transaction(node: @FlowIDTableStaking.NodeStaker) {
    
    let stakingCollectionRef: &StakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&StakingCollection.Collection>(from: StakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.addNodeObject(node: <- node)
    }
}
