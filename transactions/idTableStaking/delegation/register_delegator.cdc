import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(nodeID: String) {

    prepare(acct: AuthAccount) {

        // Create a new delegator object for the node
        let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID)

        // Store the delegator object
        acct.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)

        acct.link<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator, target: FlowIDTableStaking.DelegatorStoragePath)
    }

}