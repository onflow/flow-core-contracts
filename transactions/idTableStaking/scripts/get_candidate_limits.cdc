import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the limits for candidate nodes for each role
pub fun main(): {UInt8: UInt64} {
    return FlowIDTableStaking.getCandidateNodeLimits()
        ?? panic("Could not load candidate limits")
}