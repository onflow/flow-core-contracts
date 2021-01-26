import FlowDKG from 0xDKGADDRESS

transaction(submission: [String]) {

    let dkgParticipant: &FlowDKG.Participant

    prepare(signer: AuthAccount) {
        self.dkgParticipant = signer.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
    }

    execute {

        self.dkgParticipant.sendFinalSubmission(_ submission: submission)

    }

}