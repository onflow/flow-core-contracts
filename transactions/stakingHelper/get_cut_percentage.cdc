import FlowStakingHelper from 0x045a1763c93006ca

pub fun main(address: Address):UFix64 {
    let capability = getAccount(address)
        .getCapability(/public/linkStakingHelper)!
        .borrow<&Capability>()!
        .borrow<&FlowStakingHelper.StakingHelper>()!

    let cutPercentage = capability.cutPercentage
    log("Cut Percentage: ".concat(cutPercentage.toString()))
    
    return cutPercentage
}
 