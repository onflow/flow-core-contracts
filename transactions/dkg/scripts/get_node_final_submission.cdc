import FlowDKG from 0xDKGADDRESS

pub fun main(nodeID: String): [String?] {
    return FlowDKG.getNodeFinalSubmission(nodeID)!
}