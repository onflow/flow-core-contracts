import FlowClusterQC from 0xQCADDRESS

// Returns a boolean indicating if a node is registered for voting

pub fun main(nodeID: String): Bool {

    return FlowClusterQC.voterIsRegistered(nodeID)

}