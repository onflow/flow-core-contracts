import "FlowDKG"

// Used by DKG participants to submit their final submission for the current DKG instance.
// This transaction is used when the participant locally failed the DKG process, and are
// recording this by submitting an empty result. For non-empty submissions, use "send_final_submission".
transaction() {

    let dkgParticipant: &FlowDKG.Participant
    let submission: FlowDKG.ResultSubmission

    prepare(signer: auth(BorrowValue) &Account) {
        self.dkgParticipant = signer.storage.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
            ?? panic("Cannot borrow DKG Participant reference from path "
                    .concat(FlowDKG.ParticipantStoragePath.toString())
                    .concat(". The signer needs to ensure their account is initialized with the DKG Participant resource."))
        self.submission = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: nil, idMapping: nil)
    }

    execute {
        self.dkgParticipant.sendFinalSubmission(self.submission)
    }
}