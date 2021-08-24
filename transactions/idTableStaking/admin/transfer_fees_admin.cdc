import FlowFees from 0xFLOWFEESADDRESS

transaction {

    prepare(owner: AuthAccount, receiver: AuthAccount) {

        // Link the staking admin capability to a private place
        let feesAdmin <- owner.load<@FlowFees.Administrator>(from: /storage/flowFeesAdmin)!

        // Save the capability to the receiver's account storage
        receiver.save(<-feesAdmin, to: /storage/flowFeesAdmin)
    }

}
 
