import LockedTokens from 0xLOCKEDTOKENADDRESS

access(all) fun main(accounts: [Address]): [UFix64] {

    var limits: [UFix64] = []

    for account in accounts {
        let lockedAccountInfoRef = getAccount(account)
            .getCapability<&LockedTokens.TokenHolder>(
                LockedTokens.LockedAccountInfoPublicPath
            )
            .borrow()
            ?? panic("Could not borrow a reference to public LockedAccountInfo")

        limits.append(lockedAccountInfoRef.getUnlockLimit())
    }

    return limits
}
