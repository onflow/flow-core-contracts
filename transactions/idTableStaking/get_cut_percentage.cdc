import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the balance of staked tokens of a node

pub fun main(): UFix64 {
    return FlowIDTableStaking.getRewardCutPercentage()
}