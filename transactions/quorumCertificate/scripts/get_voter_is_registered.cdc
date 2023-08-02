import FlowClusterQC from 0xQCADDRESS

// Returns a boolean indicating if a node is registered for voting

access(all) fun main(nodeID: String): Bool {

    return FlowClusterQC.voterIsRegistered(nodeID)

}