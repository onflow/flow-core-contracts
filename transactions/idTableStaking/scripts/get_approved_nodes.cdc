import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the current approved list

pub fun main(): [String] {
    return FlowIDTableStaking.getApprovedList()
}