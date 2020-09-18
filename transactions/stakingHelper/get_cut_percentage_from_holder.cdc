import FlowStakingHelper from 0x045a1763c93006ca

pub fun main(address: Address):UFix64 {
    let ref = getAccount(address)
        .getCapability(/public/flowStakingHelper)!
        .borrow<&FlowStakingHelper.StakingHelper>()!
    
    let cut = ref.cutPercentage;
    log("CUT: ".concat(cut.toString()));
    
    return cut
}