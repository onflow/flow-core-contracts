import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

/// Commits rewarded tokens to stake for all nodes and delegators in a collection

transaction {
    
    let stakingCollectionRef: &FlowStakingCollection.StakingCollection

    prepare(account: AuthAccount) {
        self.stakingCollectionRef = account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow ref to StakingCollection")
    }

    execute {
        let nodeIDs = self.stakingCollectionRef.getNodeIDs()

        for nodeID in nodeIDs {
            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
            self.stakingCollectionRef.stakeRewardedTokens(nodeID: nodeID, delegatorID: nil, amount: nodeInfo.tokensRewarded)
        }

        let delegators = self.stakingCollectionRef.getDelegatorIDs()

        for delegator in delegators {
            let delegatorInfo = FlowIDTableStaking.DelegatorInfo(nodeID: delegator.delegatorNodeID, delegatorID: delegator.delegatorID)
            
            self.stakingCollectionRef.stakeRewardedTokens(nodeID: delegator.delegatorNodeID, delegatorID: delegator.delegatorID, amount: delegatorInfo.tokensRewarded)
        }
    }
}
