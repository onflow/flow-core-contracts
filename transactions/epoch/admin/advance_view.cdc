import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(phase: String) {
    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        if phase == "EPOCHSETUP" {
            let ids = FlowIDTableStaking.getProposedNodeIDs()

            let approvedIDs: {String: Bool} = {}
            for id in ids {
                // Here is where we would make sure that each node's 
                // keys and addresses are correct, they haven't committed any violations,
                // and are operating properly
                // for now we just set approved to true for all
                approvedIDs[id] = true
            }
            heartbeat.endStakingAuction(approvedIDs: approvedIDs)
        } else if phase == "EPOCHCOMMITTED" {
            heartbeat.startEpochCommitted()
        } else if phase == "ENDEPOCH" {
            heartbeat.endEpoch()
        } else if phase == "BLOCK" {
            heartbeat.advanceBlock()
        }
    }
}