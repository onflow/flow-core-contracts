import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS


transaction(amount: UFix64) {

    // Local variable for a reference to the Delegator object
    let delegatorRef: &FlowIDTableStaking.NodeDelegator

    prepare(acct: AuthAccount) {
        // borrow a reference to the delegator object
        self.delegatorRef = acct.borrow<&FlowIDTableStaking.NodeDelegator>(from: FlowIDTableStaking.DelegatorStoragePath)
            ?? panic("Could not borrow reference to delegator")

    }

    execute {

        self.delegatorRef.delegateRewardedTokens(amount: amount)

    }
}