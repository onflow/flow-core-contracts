import "FlowIDTableStaking"

// This script returns the balance of staked tokens of a delegator

access(all) fun main(nodeID: String, delegatorID: UInt32): UFix64 {
    let delInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
    return delInfo.tokensStaked
}