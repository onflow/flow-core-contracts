import "FlowIDTableStaking"

// This script returns the current approved list

access(all) fun main(): [String] {
    let approveList = FlowIDTableStaking.getApprovedList()
        ?? panic("Could not read approved list from storage")

    return approveList.keys
}