import "FlowFees"

// Returns the addresses of all accounts that may receive transaction
// fee deposits, i.e. the possible `to` addresses of the deposit events
// emitted when fees are collected: the FlowFees account plus any
// child fee accounts.
// Note that fees received by the FlowFees account itself are held in
// the FlowFees contract's internal vault, not in the account's default
// FLOW vault, so they are not reflected in that account's balance.
access(all) fun main(): [Address] {
    return FlowFees.getFeeReceiverAddresses()
}
