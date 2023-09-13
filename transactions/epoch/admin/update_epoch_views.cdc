import FlowEpoch from 0xEPOCHADDRESS

transaction(newAuctionViews: UInt64) {
    prepare(signer: storage.) {
        let epochAdmin = signer.storage.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateEpochViews(newAuctionViews)
    }
}