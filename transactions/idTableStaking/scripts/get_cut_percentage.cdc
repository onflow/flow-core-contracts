import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the balance of staked tokens of a node

access(all) fun main(): UFix64 {
    return FlowIDTableStaking.getRewardCutPercentage()
}