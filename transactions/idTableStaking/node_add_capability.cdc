import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

// This transaction adds a public node capability to an account with
// an existing NodeStaker object

transaction {

    prepare(acct: AuthAccount) {
        
        if acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) != nil {

            let nodeCapability = acct.getCapability<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath)!

            let nodeRef = nodeCapability.borrow() 
            
            if nodeRef == nil {
                acct.link<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath, target: FlowIDTableStaking.NodeStakerStoragePath)
            }
        } 
    }
}