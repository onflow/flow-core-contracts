import FlowStorageFees from 0xFLOWSTORAGEFEES

transaction(flowAmount: UFix64) {

    prepare(account: AuthAccount) {
        // Get a reference to the signer's stored storageReservation
        let storageCapacityRef = account.borrow<&FlowStorageFees.StorageReservation>(from: FlowStorageFees.storageReservationPath)
			?? panic("Could not borrow reference to the owner's StorageReservation!")

        // Refund tokens from the signer's stored storageReservation
        let refunded <- storageCapacityRef.withdraw(amount: flowAmount)

        // Get a reference to the signer's Receiver
        self.receiverRef = account.getCapability(/public/flowTokenReceiver)!.borrow<&{FungibleToken.Receiver}>()
			?? panic("Could not borrow receiver reference to the recipient's Vault")

        // Deposit the refunded tokens
        self.receiverRef.deposit(from: <- refunded)
    }

}