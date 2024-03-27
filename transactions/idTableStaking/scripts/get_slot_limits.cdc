import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the slot limits for node roles

access(all) fun main(role: UInt8): UInt16 {
    let slotLimit = FlowIDTableStaking.getRoleSlotLimits()[role]
        ?? panic("Could not find slot limit for the specified role")

    return slotLimit
}