import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the list of non-operational nodes

pub fun main(): Int {
    return FlowIDTableStaking.getCandidateNodeLimit()
        ?? panic("Could not load candidate limit")
}