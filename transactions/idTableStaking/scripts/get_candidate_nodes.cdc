import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the list of candidate nodes
// for the upcoming epoch
pub fun main(): {UInt8: {String: Bool}} {
    return FlowIDTableStaking.getCandidateNodeList()
}