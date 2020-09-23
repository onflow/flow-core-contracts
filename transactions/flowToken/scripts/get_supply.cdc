// This script reads the total supply field
// of the FlowToken smart contract

import FlowToken from 0xTOKENADDRESS

pub fun main(): UFix64 {

    let supply = FlowToken.totalSupply

    return supply
}