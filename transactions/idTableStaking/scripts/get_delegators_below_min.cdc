import FlowIDTableStaking from "FlowIDTableStaking"

// This script finds all of a node's delegators who are staked above zero
// but below the minimum of 50 FLOW and returns information about them

access(all) struct DelegatorBelowMinInfo {

    access(all) var totalStaked: UFix64
    access(all) var totalBelowMinimumStaked: UFix64

    access(all) var numDelegators: Int
    access(all) var numDelegatorsBelowMin: Int

    access(all) var delegatorInfoBelowMin: [FlowIDTableStaking.DelegatorInfo]

    init(numDelegators: Int) {
        self.totalStaked = 0.0
        self.totalBelowMinimumStaked = 0.0
        self.numDelegators = numDelegators
        self.numDelegatorsBelowMin = 0
        self.delegatorInfoBelowMin = []
    }

    access(all) fun addTotalStaked(_ stake: UFix64) {
        self.totalStaked = self.totalStaked + stake
    }

    access(all) fun addBelowMinStaked(_ stake: UFix64) {
        self.totalBelowMinimumStaked = self.totalBelowMinimumStaked + stake
    }

    access(all) fun addDelegatorBelowMin() {
        self.numDelegatorsBelowMin = self.numDelegatorsBelowMin + 1
    }

    access(all) fun addDelegatorInfo(_ info: FlowIDTableStaking.DelegatorInfo) {
        self.delegatorInfoBelowMin.append(info)
    }
}

access(all) fun main(nodeID: String): DelegatorBelowMinInfo {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)

    let delegators = nodeInfo.delegators

    let belowMinimum = DelegatorBelowMinInfo(numDelegators: delegators.length)

    for delegatorID in delegators {
        let delInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)

        belowMinimum.addTotalStaked(delInfo.tokensStaked)

        if delInfo.tokensStaked < 50.0 && delInfo.tokensStaked > 0.0 {
            belowMinimum.addDelegatorInfo(delInfo)
            belowMinimum.addDelegatorBelowMin()
            belowMinimum.addBelowMinStaked(delInfo.tokensStaked)
        }
    }

    return belowMinimum
}
