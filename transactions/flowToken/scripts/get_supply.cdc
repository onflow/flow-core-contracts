// This script reads the total supply field
// of the FlowToken smart contract

import FlowToken from 0xFLOWTOKENADDRESS

pub fun main(): UFix64 {

    let supply = FlowToken.totalSupply

    return supply
}