import "FlowStorageFees"

// This transaction changes the flow storage fees parameters
transaction(storageBytesPerReservedFLOW: UFix64?, minimumStorageReservation: UFix64?) {
    
    let adminRef: &FlowStorageFees.Administrator

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the admin object
        self.adminRef = acct.storage.borrow<&FlowStorageFees.Administrator>(from: /storage/storageFeesAdmin)
            ?? panic("Could not borrow reference to storage fees admin")
    }

    execute {
        if storageBytesPerReservedFLOW != nil {
            self.adminRef.setStorageMegaBytesPerReservedFLOW(storageBytesPerReservedFLOW!)
        }
        if minimumStorageReservation != nil {
            self.adminRef.setMinimumStorageReservation(minimumStorageReservation!)
        }
    }
}