import FungibleToken from 0xee82856bf20e2aa6
import FlowStakingHelper from 0x045a1763c93006ca

pub fun main(address: Address):UFix64 {
    log(address)
    let capability = getAccount(address)
        .getCapability(/public/linkStakingHelper)!
        .borrow<&Capability>()!
        .borrow<&FlowStakingHelper.StakingHelper>()!

    let vaultRef = &capability.escrowVault as &FungibleToken.Vault
    let balance = vaultRef.balance;
    log("Balance:".concat(balance.toString()))
    
    return balance
}
