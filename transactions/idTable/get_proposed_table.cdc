import FlowIdentityTable from 0xIDENTITYTABLEADDRESS

// This script returns the proposed identity table for the next epoch

pub fun main(): Int {
    let nodeInfo = FlowIdentityTable.getAllProposedNodeInfo()

    return nodeInfo.keys.length
}