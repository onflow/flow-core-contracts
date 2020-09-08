import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the role of a node
// You must fill in `{EPOCHPHASE}` with 
// `Current`, `Previous`, or `Proposed` with the correct phase

pub fun main(nodeID: String): UInt8 {
    return FlowIDTableStaking.getNodeRole(nodeID)!
}