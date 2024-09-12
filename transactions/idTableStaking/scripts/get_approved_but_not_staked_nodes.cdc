import FlowIDTableStaking from 0x8624b52f9ddcd04a

// This script returns the list of nodes that are on the approved list but do not currently have tokens staked above the minimum requirement.
pub fun main(): [String] {
    let approvedIDs = FlowIDTableStaking.getApprovedList()?.keys ?? panic("Could not read approve list from storage")
    let stakedIDs = FlowIDTableStaking.getStakedNodeIDs()

    let stakedIDsMap: {String: Bool} = {}
    for stakedID in stakedIDs {
        stakedIDsMap[stakedID] = true
    }

    let extraNodeIDs: [String] = []
    for approvedID in approvedIDs {
        if stakedIDsMap[approvedID] != true {
            extraNodeIDs.append(approvedID)
        }
    }
    return extraNodeIDs
}