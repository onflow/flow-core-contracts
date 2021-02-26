import FlowEpoch from 0xEPOCHADDRESS

transaction(newPhaseViews: UInt64) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow(from: FlowEpoch.epochAdminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateDKGPhaseViews(newPhaseViews)
    }
}