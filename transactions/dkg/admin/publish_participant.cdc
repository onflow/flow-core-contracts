import FlowDKG from 0xDKGADDRESS

// This transaction is only for testing!

transaction {

    prepare(signer: AuthAccount) {

        signer.link<&FlowDKG.Admin>(/public/dkgAdmin, target: FlowDKG.AdminStoragePath)

    }

}