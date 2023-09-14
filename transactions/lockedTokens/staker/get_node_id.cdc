import LockedTokens from 0xLOCKEDTOKENADDRESS

access(all) fun main(account: Address): String {

    let lockedAccountInfoRef = getAccount(account)
        .capabilities.borrow<&LockedTokens.TokenHolder>(
            LockedTokens.LockedAccountInfoPublicPath
        )
        ?? panic("Could not borrow a reference to public LockedAccountInfo")

    return lockedAccountInfoRef.getNodeID()!
}
