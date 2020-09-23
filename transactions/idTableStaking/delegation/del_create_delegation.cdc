import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction() {

    prepare(acct: AuthAccount) {

        // Create a public link to the node staker
        // so that delegators can access the function to register as a delegator
        let linkPath = FlowIDTableStaking.NodeStakerPublicPath
        let storagePath = FlowIDTableStaking.NodeStakerStoragePath

        acct.link<&FlowIDTableStaking.NodeStaker{FlowIDTableStaking.PublicNodeStaker}>(linkPath, target: storagePath)
    }

}