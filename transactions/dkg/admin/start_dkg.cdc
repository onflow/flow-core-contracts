import "FlowDKG"

transaction(nodeIDs: [String]) {

    let dkgAdmin: &FlowDKG.Admin

    prepare(signer: auth(BorrowValue) &Account) {
        self.dkgAdmin = signer.storage.borrow<&FlowDKG.Admin>(from: FlowDKG.AdminStoragePath)
            ?? panic("Could not borrow DKG Admin reference")
    }

    execute {
        self.dkgAdmin.startDKG(nodeIDs: nodeIDs)
    }
}
