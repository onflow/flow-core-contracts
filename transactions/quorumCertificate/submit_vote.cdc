import FlowClusterQC from 0xQCADDRESS

// A node voter uses this transaction to submit a QC vote
//
// Parameters:
// 
// voteSignature: The signed message using the node's staking key
// voteMessage: The hex-encoded string of the raw message

transaction(voteSignature: String, voteMessage: String) {

    prepare(signer: AuthAccount) {
        let voterRef = signer.borrow<&FlowClusterQC.Voter>(from: FlowClusterQC.VoterStoragePath)
            ?? panic("Could not borrow reference to qc voter")

        voterRef.vote(voteSignature: voteSignature, voteMessage: voteMessage)
    }
}