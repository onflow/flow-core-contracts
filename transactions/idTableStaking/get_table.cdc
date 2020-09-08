import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the current identity table length

pub fun main(): [String] {
    return FlowIDTableStaking.getNodeIDs()
}