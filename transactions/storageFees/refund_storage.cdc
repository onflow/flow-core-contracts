import StorageFees from 0xSTORAGEFEES

transaction(storageAmount: UInt64) {

    prepare(account: AuthAccount) {
        // Round up storage to the closest unit
        let storage = StorageFees.roundDownStorageCapacity(storageAmount)


        // Get a reference to the signer's stored storageCapacity
        let storageCapacityRef = signer.borrow<&StorageFees.StorageCapacity>(from: /storage/storageCapacity)
			?? panic("Could not borrow reference to the owner's StorageCapacity!")

        
        // Refund tokens from the signer's stored storageCapacity
        let refunded <- StorageFees.refundStorageCapacity(storageCapacityReference: storageCapacityRef, storageAmount: storage)

        // Get a reference to the signer's Receiver
        self.receiverRef = signer.getCapability(/public/flowTokenReceiver)!.borrow<&{FungibleToken.Receiver}>()
			?? panic("Could not borrow receiver reference to the recipient's Vault")

        // Deposit the refunded tokens
        self.receiverRef.deposit(from: <- refunded)
    }

}