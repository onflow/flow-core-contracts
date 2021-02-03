import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

// This transaction adds a public delegator capability to an account with
// an existing NodeDelegator object

transaction {

    prepare(acct: AuthAccount) {

        if acct.borrow<&FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath) == nil ||
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