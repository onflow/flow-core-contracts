import "FlowClusterQC"

// Returns a boolean indicating if a node has submitted a vote for this epoch

access(all) fun main(): Bool {

    return FlowClusterQC.votingCompleted()

}