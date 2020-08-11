import FlowIdentityTable from 0xIDENTITYTABLEADDRESS

// This transaction removes an existing node from the proposed identity table

transaction(id: String) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIdentityTable.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIdentityTable.Admin>(from: /storage/flowIdentityTableAdmin)
            ?? panic("Could not borrow reference to ID Table admin")
    }

    execute {
        self.adminRef.removeProposedNode(id)
    }
}