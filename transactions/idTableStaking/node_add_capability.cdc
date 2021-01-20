import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

// This transaction adds a public node capability to an account with
// an existing NodeStaker object

transaction {

    prepare(acct: AuthAccount) {

        if acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil ||
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