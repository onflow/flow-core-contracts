import FlowIDTableStaking from 0x8624b52f9ddcd04a

// This script returns the list of candidate nodes
// for the upcoming epoch
pub fun main(): {UInt8: {String: Bool}} {
    return FlowIDTableStaking.getCandidateNodeList()
}
