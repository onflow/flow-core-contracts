import "FlowIDTableStaking"

// This script returns the limits for candidate nodes for each role
access(all) fun main(): {UInt8: UInt64} {
    return FlowIDTableStaking.getCandidateNodeLimits()
        ?? panic("Could not load candidate limits")
}