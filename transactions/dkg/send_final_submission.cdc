import FlowDKG from 0xDKGADDRESS

transaction(submission: [String?]) {

    let dkgParticipant: &FlowDKG.Participant

    prepare(signer: auth(BorrowValue) &Account) {
        self.dkgParticipant = signer.storage.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
            ?? panic("Cannot borrow dkg participant reference")
    }

    execute {
        self.dkgParticipant.sendFinalSubmission(submission)
    }
}