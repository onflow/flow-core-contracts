import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the current approved list

pub fun main(): [String] {
    let approveList = FlowIDTableStaking.getApprovedList()
        ?? panic("Could not read approved list from storage")

    return approveList.keys
}