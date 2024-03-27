import FlowDKG from "FlowDKG"

access(all) fun main(nodeID: String): Bool {
    return FlowDKG.participantIsRegistered(nodeID)
}