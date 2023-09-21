import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"

// This transaction adds a public node capability to an account with
// an existing NodeStaker object

transaction {

    prepare(acct: auth(BorrowValue) &Account) {

        if acct.storage.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil ||
            acct.capabilities.get<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath)?.check() ?? false
        {
            return
        }

        let nodeStakerCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeStakerPublic}>(
            FlowIDTableStaking.NodeStakerStoragePath
        )

        acct.capabilities.publish(
            nodeStakerCap,
            at: FlowIDTableStaking.NodeStakerPublicPath
        )
    }
}