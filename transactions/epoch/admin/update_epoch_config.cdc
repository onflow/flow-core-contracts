import FlowEpoch from 0xEPOCHADDRESS

transaction(dkgPhaseLen: UInt64, stakingLen: UInt64, epochLen: UInt64) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        if !FlowEpoch.isValidPhaseConfiguration(stakingLen, dkgPhaseLen, epochLen) {
            panic("New Epoch Views must be greater than the sum of staking and DKG Phase views")
        }

        /// Due to the fact that epoch Views must be greater than the sum of staking and DKG Phase views
        /// we must update the epoch config in the correct order. This validation is done on each epoch config
        /// update. How the number of views in the epoch is being updated determines the order
        /// in which numViewsInEpoch, numViewsInStakingAuction, and numViewsInDKGPhase need to be updated such that the validation passes.
        /// - increasing numViewsInEpoch: update numViewsInEpoch before numViewsInStakingAuction, and numViewsInDKGPhase
        /// - decreasing numViewsInEpoch: update numViewsInStakingAuction and  numViewsInDKGPhase before numViewsInStakingAuction
        /// NOTE: We assume here that the DKG phase length is much smaller than the staking length for all potential configurations.
        if newEpochViews > FlowEpoch.getConfigMetadata().numViewsInEpoch  {
            epochAdmin.updateEpochViews(epochLen)
            epochAdmin.updateAuctionViews(stakingLen)
            epochAdmin.updateDKGPhaseViews(dkgPhaseLen)
        } else {
            epochAdmin.updateAuctionViews(stakingLen)
            epochAdmin.updateDKGPhaseViews(dkgPhaseLen)
            epochAdmin.updateEpochViews(epochLen)
        }
    }
}