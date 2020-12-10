import FlowStorageFees from 0xFLOWSTORAGEFEES

// This transaction changes the flow storage fees parameters
transaction(refundingEnabled: Bool?, storageBytesPerReservedFLOW: UFix64?, minimumStorageReservation: UFix64?) {
    let adminRef: &FlowStorageFees.Administrator

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowStorageFees.Administrator>(from: /storage/storageFeesAdmin)
            ?? panic("Could not borrow reference to storage fees admin")
    }

    execute {
        if refundingEnabled != nil {
            self.adminRef.setRefundingEnabled(refundingEnabled!)
        }
        if storageBytesPerReservedFLOW != nil {
            self.adminRef.setStorageBytesPerReservedFLOW(storageBytesPerReservedFLOW!)
        }
        if minimumStorageReservation != nil {
            self.adminRef.setMinimumStorageReservation(minimumStorageReservation!)
        }
    }
}