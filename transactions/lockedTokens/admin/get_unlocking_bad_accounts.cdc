

access(all) fun main(tokenAdmin: Address): {Address: UFix64} {

    let copyofDictionary: {Address: UFix64} = {}

    let account = getAccount(tokenAdmin)
    
    let dictionaryReference = account.capabilities.borrow<&{Address: UFix64}>(/public/unlockingBadAccounts)
        ?? panic("Could not get bad accounts dictionary")

    for address in dictionaryReference.keys {
        copyofDictionary[address] = dictionaryReference[address]!
    }

    return copyofDictionary
}