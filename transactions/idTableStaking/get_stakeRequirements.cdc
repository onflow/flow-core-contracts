import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the balance of staked tokens of a node

pub fun main(role: UInt8): UFix64 {
    let req = FlowIDTableStaking.getMinimumStakeRequirements()

    return req[role]!
}