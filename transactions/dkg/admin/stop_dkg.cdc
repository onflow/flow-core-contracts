import FlowDKG from 0xDKGADDRESS

transaction {

    let dkgAdmin: &FlowDKG.Admin

    prepare(signer: AuthAccount) {

        self.dkgAdmin = signer.borrow<&FlowDKG.Admin>(from: FlowDKG.AdminStoragePath)

    }

    execute {

        self.dkgAdmin.endDKG()

    }

}