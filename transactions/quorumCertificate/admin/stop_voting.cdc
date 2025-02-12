import "FlowClusterQC"

// Test transaction for the QC contract to stop the voting period

transaction {

    prepare(signer: auth(BorrowValue) &Account) {
        let adminRef = signer.storage.borrow<&FlowClusterQC.Admin>(from: FlowClusterQC.AdminStoragePath)
            ?? panic("Could not borrow reference to qc admin")

        adminRef.stopVoting()
    }
}