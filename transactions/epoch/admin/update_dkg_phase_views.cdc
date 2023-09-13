import FlowEpoch from 0xEPOCHADDRESS

transaction(newPhaseViews: UInt64) {
    prepare(signer: storage.) {
        let epochAdmin = signer.storage.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateDKGPhaseViews(newPhaseViews)
    }
}