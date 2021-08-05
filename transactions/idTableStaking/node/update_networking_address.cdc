import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

transaction(newAddress: String) {

    // Local variable for a reference to the node object
    let stakerRef: &FlowIDTableStaking.NodeStaker

    prepare(acct: AuthAccount) {
        // borrow a reference to the node object
        self.stakerRef = acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {

        self.stakerRef.updateNetworkingAddress(newAddress)

    }
}