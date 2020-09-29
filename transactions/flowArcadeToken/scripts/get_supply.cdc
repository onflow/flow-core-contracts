// This script reads the total supply field
// of the FlowArcadeToken smart contract

import FlowArcadeToken from 0xARCADETOKENADDRESS

pub fun main(): UFix64 {

    let supply = FlowArcadeToken.totalSupply

    return supply
}