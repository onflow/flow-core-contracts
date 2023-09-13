import FlowDKG from 0xDKGADDRESS

// This transaction is only for testing!

transaction {

    prepare(signer: auth(Capabilities) &Account) {
        let adminCap = signer.capabilities.storage.issue<&FlowDKG.Admin>(FlowDKG.AdminStoragePath)
        signer.capabilities.publish(adminCap, at: /public/dkgAdmin)
    }
}
