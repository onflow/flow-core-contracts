import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction {
    prepare(signer: AuthAccount) {
        let heartbeat = signer.borrow<&FlowEpoch.Heartbeat>(from: FlowEpoch.heartbeatStoragePath)
            ?? panic("Could not borrow heartbeat from storage path")

        let previousEpochMetadata = FlowEpoch.getEpochMetadata(FlowEpoch.currentEpochCounter - (1 as UInt64))!

        heartbeat.payRewards(previousEpochMetadata.totalRewards)
    }
}