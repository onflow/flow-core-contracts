import FlowDKG from "FlowDKG"

access(all) fun main(nodeID: String): Bool {
    if FlowDKG.participantIsClaimed(nodeID) != nil {
        return FlowDKG.participantIsClaimed(nodeID)!
    } else {
        return false
    }
}