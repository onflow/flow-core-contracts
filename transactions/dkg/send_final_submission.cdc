import FlowDKG from "FlowDKG"

// TODO: way to submit nil/failure result
transaction(groupKey: String, pubKeys: [String], idMapping: {String: Int}) {

    let dkgParticipant: &FlowDKG.Participant
    let submission: FlowDKG.ResultSubmission

    prepare(signer: auth(BorrowValue) &Account) {
        self.dkgParticipant = signer.storage.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
            ?? panic("Cannot borrow dkg participant reference")
        self.submission = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    }

    execute {
        self.dkgParticipant.sendFinalSubmission(self.submission)
    }
}