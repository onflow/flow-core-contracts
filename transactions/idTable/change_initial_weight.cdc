import FlowIdentityTable from 0xIDENTITYTABLEADDRESS

// This transaction calls the function that assigns the proposed identity table
// to the current table, and assigns the current table to the previous table
// It will only be called at the beginning of a new epoch

transaction(id: String, newWeight: UInt64, counter: UInt64) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIdentityTable.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIdentityTable.Admin>(from: /storage/flowIdentityTableAdmin)
            ?? panic("Could not borrow reference to ID Table admin")
    }

    execute {
        // Use the admin reference to update the weight
        self.adminRef.updateInitialWeight(epochCounter: counter, id, newWeight: newWeight)
    }
}