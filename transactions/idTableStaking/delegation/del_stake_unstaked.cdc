import FlowIDTableStaking from "FlowIDTableStaking"


transaction(amount: UFix64) {

    // Local variable for a reference to the Delegator object
    let delegatorRef: auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator

    prepare(acct: AuthAccount) {
        // borrow a reference to the delegator object
        self.delegatorRef = acct.borrow<auth(FlowIDTableStaking.DelegatorOwner) &FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath)
            ?? panic("Could not borrow reference to delegator")

    }

    execute {

        self.delegatorRef.delegateUnstakedTokens(amount: amount)

    }
}