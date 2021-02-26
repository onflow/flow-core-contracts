import FlowEpoch from 0xEPOCHADDRESS

transaction(phase: Int) {
    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        if phase == 0 {
            heartbeat.endStakingAuction()
        } else if phase == 1 {
            heartbeat.endEpochSetup()
        } else if phase == 2 {
            heartbeat.endEpoch()
        } else {
            heartbeat.advanceBlock()
        }
    }
}