import FlowFees from 0xFLOWFEESADDRESS

transaction {

    prepare(owner: auth(LoadValue) &Account, receiver: auth(SaveValue) &Account) {

        // Link the staking admin capability to a private place
        let feesAdmin <- owner.storage.load<@FlowFees.Administrator>(from: /storage/flowFeesAdmin)!

        // Save the capability to the receiver's account storage
        receiver.storage.save(<-feesAdmin, to: /storage/flowFeesAdmin)
    }

}
 
