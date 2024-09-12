import FlowIDTableStaking from 0x8624b52f9ddcd04a

// This script returns the current approved list

pub fun main(): [String] {
    let approveList = FlowIDTableStaking.getApprovedList()
        ?? panic("Could not read approved list from storage")

    return approveList.keys
}