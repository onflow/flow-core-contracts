import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the balance of staked tokens of a node

access(all) fun main(role: UInt8): UFix64 {
    let staked = FlowIDTableStaking.getTotalTokensStakedByNodeType()

    return staked[role]!
}