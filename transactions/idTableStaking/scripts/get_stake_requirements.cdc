import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the balance of staked tokens of a node

access(all) fun main(role: UInt8): UFix64 {
    let req = FlowIDTableStaking.getMinimumStakeRequirements()

    return req[role]!
}