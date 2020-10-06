import LockedTokens from 0xf3fcd2c1a78f5eee

pub fun main(account: Address): UFix64 {

    let holderRef = getAccount(account).getCapability<&LockedTokens.TokenHolder{LockedTokens.UnlockLimit}>(LockedTokens.UnlockLimitPublicPath)!
        .borrow() ?? panic("Could not borrow a reference to public TokenHolder unlock limit")

    return holderRef.getUnlockLimit()
}
