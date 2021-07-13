import FlowClusterQC from 0xQCADDRESS

// Returns a boolean indicating if a node has submitted a vote for this epoch

pub fun main(): Bool {

    return FlowClusterQC.votingCompleted()

}