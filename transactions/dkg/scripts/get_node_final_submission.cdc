import FlowDKG from "FlowDKG"

access(all) fun main(nodeID: String): [String?] {
    return FlowDKG.getNodeFinalSubmission(nodeID)!
}