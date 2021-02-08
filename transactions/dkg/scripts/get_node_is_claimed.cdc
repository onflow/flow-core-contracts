import FlowDKG from 0xDKGADDRESS

pub fun main(nodeID: String): Bool {
    if FlowDKG.participantIsClaimed(nodeID) != nil {
        return FlowDKG.participantIsClaimed(nodeID)!
    } else {
        return false
    }
}