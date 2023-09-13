import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"

transaction(nodeIDs: [String], paths: [StoragePath]) {

    prepare(acct: auth(SaveValue) &Account) {

        var i = 0

        for path in paths {
            // Create a new delegator object for the node
            let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeIDs[i], tokensCommitted: <-FlowToken.createEmptyVault())

            // Store the delegator object
            acct.storage.save(<-newDelegator, to: path)

            i = i + 1
            if i == nodeIDs.length {
                i = 0
            }
        }
    }

}