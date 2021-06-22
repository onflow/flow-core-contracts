import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(nodeIDs: [String], paths: [StoragePath]) {

    prepare(acct: AuthAccount) {

        var i = 0

        for path in paths {
            // Create a new delegator object for the node
            let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeIDs[i])

            // Store the delegator object
            acct.save(<-newDelegator, to: path)

            i = i + 1
            if i == nodeIDs.length {
                i = 0
            }
        }
    }

}