import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the slot limits for node roles

access(all) fun main(): {UInt8: UInt16} {
    return FlowIDTableStaking.getCurrentRoleNodeCounts()
}