import FlowEpochClusterQC from 0xQCADDRESS

// Test transaction for the QC admin to publish a reference
// that allows accounts to register for QC voting

transaction {

    prepare(signer: AuthAccount) {
        signer.link<&FlowEpochClusterQC.Admin>(/public/voterCreator, target: FlowEpochClusterQC.AdminStoragePath)
    }
}