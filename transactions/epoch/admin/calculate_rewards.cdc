import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from "FlowIDTableStaking"

transaction() {
    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        heartbeat.calculateAndSetRewards()
    }
}