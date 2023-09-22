import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"

// This transaction adds a public delegator capability to an account with
// an existing NodeDelegator object

transaction {

    prepare(acct: auth(BorrowValue) &Account) {

        if acct.storage.borrow<auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath) == nil ||
            acct.capabilities.get<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator)!.check()
        {
            return
        }

        let delegatorCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeDelegatorPublic}>(
            FlowIDTableStaking.DelegatorStoragePath
        )
        acct.capabilities.publish(
            delegatorCap,
            at: /public/flowStakingDelegator
        )
    }
}