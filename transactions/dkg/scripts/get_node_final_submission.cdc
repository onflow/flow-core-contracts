import FlowDKG from "FlowDKG"

access(all) fun main(nodeID: String): FlowDKG.ResultSubmission {
    return FlowDKG.getNodeFinalSubmission(nodeID)!
}