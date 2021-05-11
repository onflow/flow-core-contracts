import FlowEpoch from 0xEPOCHADDRESS

pub fun main(nodeID: String): Address {
    return FlowEpoch.getMachineAccountForNode(nodeID)
        ?? panic("Invalid Node ID for machine account")
}