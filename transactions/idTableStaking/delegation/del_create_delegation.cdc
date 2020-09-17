import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction() {

    prepare(acct: AuthAccount) {

        // Create a public link to the node staker
        // so that delegators can access the function to register as a delegator
        acct.link<&FlowIDTableStaking.NodeStaker{PublicNodeStaker}>(FlowIDTableStaking.NodeStakerPublicPath, target: FlowIDTableStaking.NodeStakerStoragePath)
    }

}