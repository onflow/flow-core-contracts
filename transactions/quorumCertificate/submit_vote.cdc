import FlowEpochClusterQC from 0xQCADDRESS

// A node voter uses this transaction to submit a QC vote

transaction(rawVote: String) {

    prepare(signer: AuthAccount) {
        let voterRef = signer.borrow<&FlowEpochClusterQC.Voter>(from: FlowEpochClusterQC.VoterStoragePath)
            ?? panic("Could not borrow reference to qc voter")

        voterRef.vote(rawVote)
    }
}