import FlowEpoch from 0xEPOCHADDRESS

transaction(newStakingViews: UInt64) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateAuctionViews(newStakingViews)
    }
}