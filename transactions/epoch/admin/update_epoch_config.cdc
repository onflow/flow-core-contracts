import FlowEpoch from 0xEPOCHADDRESS

transaction(newStakingViews: UInt64, newPhaseViews: UInt64, newEpochViews: UInt64) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        if !FlowEpoch.isValidPhaseConfiguration(newStakingViews, newPhaseViews, newEpochViews) {
            panic("New Epoch Views must be greater than the sum of staking and DKG Phase views")
        }

        if newEpochViews > FlowEpoch.getConfigMetadata().numViewsInEpoch  {
            epochAdmin.updateEpochViews(newEpochViews)
            epochAdmin.updateAuctionViews(newStakingViews)
            epochAdmin.updateDKGPhaseViews(newPhaseViews)
        } else {
            epochAdmin.updateAuctionViews(newStakingViews)
            epochAdmin.updateDKGPhaseViews(newPhaseViews)
            epochAdmin.updateEpochViews(newEpochViews)
        }
    }
}