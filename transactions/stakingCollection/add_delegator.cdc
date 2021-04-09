import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction(delegator: @FlowIDTableStaking.NodeDelegator) {
    
    let stakingCollectionRef: &FlowStakingCollection.Collection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.Collection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        stakingCollectionRef.addDelegatorObject(delegator: <- delegator)
    }
}
