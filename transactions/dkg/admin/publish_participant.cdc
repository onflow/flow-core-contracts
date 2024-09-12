import FlowDKG from "FlowDKG"

// This transaction is only for testing!

// TODO: rename file to publish_admin

transaction {

    prepare(signer: auth(Capabilities) &Account) {
        let adminCap = signer.capabilities.storage.issue<&FlowDKG.Admin>(FlowDKG.AdminStoragePath)
        signer.capabilities.publish(adminCap, at: /public/dkgAdmin)
    }
}
