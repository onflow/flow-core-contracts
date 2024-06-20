import FlowIDTableStaking from "FlowIDTableStaking"


transaction(amount: UFix64) {

    // Local variable for a reference to the node object
    let stakerRef: auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker

    prepare(acct: AuthAccount) {
        // borrow a reference to the node object
        self.stakerRef = acct.borrow<auth(FlowIDTableStaking.NodeOperator) &FlowIDTableStaking.NodeStaker>(from: /storage/flowStaker)
            ?? panic("Could not borrow reference to staking admin")

    }

    execute {

        self.stakerRef.stakeUnstakedTokens(amount: amount)

    }
}