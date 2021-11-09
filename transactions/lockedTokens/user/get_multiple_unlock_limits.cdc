import LockedTokens from 0xLOCKEDTOKENADDRESS

pub fun main(accounts: [Address]): [UFix64] {

    var limits: [UFix64] = []

    for account in accounts {
        let lockedAccountInfoRef = getAccount(account)
            .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(
                LockedTokens.LockedAccountInfoPublicPath
            )
            .borrow()
            ?? panic("Could not borrow a reference to public LockedAccountInfo")

        limits.append(lockedAccountInfoRef.getUnlockLimit())
    }

    return limits
}
