import FlowClusterQC from 0xQCADDRESS

// Test transaction for the QC contract to stop the voting period

transaction {

    prepare(signer: AuthAccount) {
        let adminRef = signer.borrow<&FlowClusterQC.Admin>(from: FlowClusterQC.AdminStoragePath)
            ?? panic("Could not borrow reference to qc admin")

        adminRef.stopVoting()
    }
}