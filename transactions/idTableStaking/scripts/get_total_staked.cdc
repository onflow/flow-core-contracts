import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

pub fun main(): UFix64 {
    let stakedTokens = FlowIDTableStaking.getTotalTokensStakedByNodeType()

    // calculate the total number of tokens staked
    var totalStaked: UFix64 = 0.0
    for nodeType in stakedTokens.keys {
        // Do not count access nodes
        if nodeType != UInt8(5) {
            totalStaked = totalStaked + stakedTokens[nodeType]!
        }
    }

    return totalStaked
}