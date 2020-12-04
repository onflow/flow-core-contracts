import StorageFees from 0xSTORAGEFEES

// This transaction changes the flow storage fees parameters
transaction(refundingEnabled: Bool?, storageBytesPerReservedFlow: UFix64?, minimumStorageReservation: UFix64?) {
    let adminRef: &StorageFees.Administrator

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&StorageFees.Administrator>(from: /storage/storageFeesAdmin)
            ?? panic("Could not borrow reference to storage fees admin")
    }

    execute {
        if refundingEnabled != nil {
            self.adminRef.setRefundingEnabled(refundingEnabled!)
        }
        if storageBytesPerReservedFlow != nil {
            self.adminRef.setStorageBytesPerReservedFlow(storageBytesPerReservedFlow!)
        }
        if minimumStorageReservation != nil {
            self.adminRef.setMinimumStorageReservation(minimumStorageReservation!)
        }
    }
}