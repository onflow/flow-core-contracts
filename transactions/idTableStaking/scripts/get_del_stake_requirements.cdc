import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the minimum stake requirement for delegators

pub fun main(): UFix64 {
    return FlowIDTableStaking.getDelegatorMinimumStakeRequirement()
}