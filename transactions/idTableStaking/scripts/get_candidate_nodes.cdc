import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the list of candidate nodes
// for the upcoming epoch
access(all) fun main(): {UInt8: {String: Bool}} {
    return FlowIDTableStaking.getCandidateNodeList()
}