import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"

// This transaction adds a public node capability to an account with
// an existing NodeStaker object

transaction {

    prepare(acct: AuthAccount) {

        if acct.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil ||
            acct.getCapability<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath).check()
        {
            return
        }

        acct.link<&{FlowIDTableStaking.NodeStakerPublic}>(
            FlowIDTableStaking.NodeStakerPublicPath,
            target: FlowIDTableStaking.NodeStakerStoragePath
        )
    }
}