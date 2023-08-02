import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"

// This transaction adds a public delegator capability to an account with
// an existing NodeDelegator object

transaction {

    prepare(acct: AuthAccount) {

        if acct.borrow<auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath) == nil ||
            acct.getCapability<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator).check()
        {
            return
        }

        acct.link<&{FlowIDTableStaking.NodeDelegatorPublic}>(
            /public/flowStakingDelegator,
            target: FlowIDTableStaking.DelegatorStoragePath
        )
    }
}