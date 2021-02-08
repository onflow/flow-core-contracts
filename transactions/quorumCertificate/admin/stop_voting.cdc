import FlowEpochClusterQC from 0xQCADDRESS

// Test transaction for the QC contract to stop the voting period

transaction {

    prepare(signer: AuthAccount) {
        let adminRef = signer.borrow<&FlowEpochClusterQC.Admin>(from: FlowEpochClusterQC.AdminStoragePath)
            ?? panic("Could not borrow reference to qc admin")

        adminRef.stopVoting()
    }
}