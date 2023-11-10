import FlowEpoch from 0xEPOCHADDRESS

transaction(duration: UInt64, refCounter: UInt64, refTimestamp: UInt64) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        let config = FlowEpoch.EpochTimingConfig(duration: duration, refCounter: refCounter, refTimestamp: refTimestamp)
        epochAdmin.updateEpochTimingConfig(config)
    }
}