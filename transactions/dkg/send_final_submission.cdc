import FlowDKG from "FlowDKG"

// Used by DKG participants to submit their final submission for the current DKG instance.
// This transaction is used when the participant locally passed the DKG process.
// For empty submissions, use "send_empty_final_submission".
transaction(groupKey: String, pubKeys: [String], idMapping: {String: Int}) {

    let dkgParticipant: &FlowDKG.Participant
    let submission: FlowDKG.ResultSubmission

    prepare(signer: auth(BorrowValue) &Account) {
        self.dkgParticipant = signer.storage.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
            ?? panic("Cannot borrow DKG Participant reference from path "
                    .concat(FlowDKG.ParticipantStoragePath.toString())
                    .concat(". The signer needs to ensure their account is initialized with the DKG Participant resource."))
        self.submission = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    }

    execute {
        self.dkgParticipant.sendFinalSubmission(self.submission)
    }
}