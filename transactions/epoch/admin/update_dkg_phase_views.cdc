import "FlowEpoch"

transaction(newPhaseViews: UInt64) {
    prepare(signer: auth(BorrowValue) &Account) {
        let epochAdmin = signer.storage.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateDKGPhaseViews(newPhaseViews)
    }
}