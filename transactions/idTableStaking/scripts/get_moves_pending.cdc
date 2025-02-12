import "FlowIDTableStaking"

// This script returns the current moves pending list

access(all) fun main(): {String: {UInt32: Bool}} {
    return FlowIDTableStaking.getMovesPendingList()!
}