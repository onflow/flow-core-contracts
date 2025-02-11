import "FlowDKG"

access(all) fun main(nodeID: String): FlowDKG.ResultSubmission {
    return FlowDKG.getNodeFinalSubmission(nodeID)!
}