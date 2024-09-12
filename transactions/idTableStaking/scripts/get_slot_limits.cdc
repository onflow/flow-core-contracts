// mainnet
import FlowIDTableStaking from 0x8624b52f9ddcd04a
// testnet
//import FlowIDTableStaking from 0x9eca2b38b18b5dfe

// This script returns the slot limits for node roles

pub fun main(role: UInt8): UInt16 {
    let slotLimit = FlowIDTableStaking.getRoleSlotLimits()[role]
        ?? panic("Could not find slot limit for the specified role")

    return slotLimit
}
