import FlowIdentityTable from 0xIDENTITYTABLEADDRESS

// This script returns the current identity table length

pub fun main(): Int {
    let nodeInfo = FlowIdentityTable.getAllCurrentNodeInfo()

    return nodeInfo.keys.length
}