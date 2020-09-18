import FungibleToken from 0xee82856bf20e2aa6

pub fun main(): UFix64 {
    let account = getAccount(0x01cf0e2f2f715450)
    let ref = account
        .getCapability(/public/vaultCapability)!
        .borrow<&Capability>()!
        .borrow<&FungibleToken.Vault>()!
    log("Vault Balance:".concat(ref.balance.toString()));
    
    return ref.balance
}
 