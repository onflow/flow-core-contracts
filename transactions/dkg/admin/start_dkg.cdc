import FlowDKG from 0xDKGADDRESS

transaction(nodeIDs: [String]) {

    let dkgAdmin: &FlowDKG.Admin

    prepare(signer: AuthAccount) {

        self.dkgAdmin = signer.borrow<&FlowDKG.Admin>(from: FlowDKG.AdminStoragePath)
            ?? panic("Could not borrow DKG Admin reference")

    }

    execute {

        self.dkgAdmin.startDKG(nodeIDs: nodeIDs)

    }

}