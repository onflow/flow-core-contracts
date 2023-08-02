import FlowDKG from 0xDKGADDRESS

access(all) fun main(nodeID: String): [String?] {
    return FlowDKG.getNodeFinalSubmission(nodeID)!
}