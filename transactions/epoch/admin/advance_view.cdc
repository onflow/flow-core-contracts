import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(phase: String) {
    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        if phase == "EPOCHSETUP" {
            heartbeat.endStakingAuction()
        } else if phase == "EPOCHCOMMIT" {
            heartbeat.startEpochCommit()
        } else if phase == "ENDEPOCH" {
            heartbeat.endEpoch()
        } else if phase == "BLOCK" {
            heartbeat.advanceBlock()
        }
    }
}