import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the slot limits for node roles

pub fun main(): {UInt8: UInt16} {
    return FlowIDTableStaking.getCurrentRoleNodeCounts()
}