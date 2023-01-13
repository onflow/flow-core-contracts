import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the list of non-operational nodes
pub fun main(): {UInt8: {String: Bool}} {
    return FlowIDTableStaking.getCandidateNodeList()
}