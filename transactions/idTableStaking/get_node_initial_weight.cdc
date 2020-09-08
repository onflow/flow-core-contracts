import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the initial weight of a node
// You must fill in `{EPOCHPHASE}` with 
// `Current`, `Previous`, or `Proposed` with the correct phase

pub fun main(nodeID: String): UInt64 {
    return FlowIDTableStaking.getNodeInitialWeight(nodeID)!
}