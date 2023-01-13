import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the list of non-operational nodes
pub fun main(): {UInt8: UInt64} {
    return FlowIDTableStaking.getCandidateNodeLimits()
        ?? panic("Could not load candidate limits")
}