import FlowEpoch from 0xEPOCHADDRESS

transaction(newStakingViews: UInt64) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow(from: FlowEpoch.epochAdminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateAuctionViews(newStakingViews)
    }
}