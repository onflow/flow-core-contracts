import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(nodeAddress: Address) {

    prepare(acct: AuthAccount) {
        // borrow a reference to the node object
        let nodeRef = getAccount(nodeAddress).getCapability<&FlowIDTableStaking.NodeStaker{FlowIDTableStaking.PublicNodeStaker}>(FlowIDTableStaking.NodeStakerPublicPath)!.borrow()
            ?? panic("Could not borrow reference to node staker")

        // Create a new delegator object for the node
        let newDelegator <- nodeRef.createNewDelegator()

        // Store the delegator object
        acct.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)
    }

}