import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from "FlowIDTableStaking"

/// Gets an array of all the delegator metadata for delegators stored in the staking collection

access(all) fun main(address: Address): [FlowIDTableStaking.DelegatorInfo] {
    return FlowStakingCollection.getAllDelegatorInfo(address: address)
}