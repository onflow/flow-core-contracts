import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the minimum stake requirement for delegators

access(all) fun main(): UFix64 {
    return FlowIDTableStaking.getDelegatorMinimumStakeRequirement()
}