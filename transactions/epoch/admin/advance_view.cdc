import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(phase: Int) {
    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        if phase == 0 {
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
        } else if phase == 1 {
            heartbeat.endEpochSetup()
        } else if phase == 2 {
            heartbeat.endEpoch()
        } else {
            heartbeat.advanceBlock()
        }
    }
}