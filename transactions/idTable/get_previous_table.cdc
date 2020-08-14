import FlowIdentityTable from 0xIDENTITYTABLEADDRESS

// This script returns the identity table from the previous epoch

pub fun main(): Int {
    let nodeInfo = FlowIdentityTable.getAllPreviousNodeInfo()

    return nodeInfo.keys.length
}