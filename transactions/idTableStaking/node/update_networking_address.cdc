import FlowIDTableStaking from "FlowIDTableStaking"

transaction(newAddress: String) {

    // Local variable for a reference to the node object
    let stakerRef: auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker

    prepare(acct: AuthAccount) {
        // borrow a reference to the node object
        self.stakerRef = acct.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {

        self.stakerRef.updateNetworkingAddress(newAddress)

    }
}