import LockedTokens from 0xLOCKEDTOKENADDRESS

access(all) fun main(account: Address): UInt32 {

    let lockedAccountInfoRef = getAccount(account)
        .capabilities.get<&LockedTokens.TokenHolder>(
            LockedTokens.LockedAccountInfoPublicPath
        )!
        .borrow()
        ?? panic("Could not borrow a reference to public LockedAccountInfo")

    return lockedAccountInfoRef.getDelegatorID()!
}
