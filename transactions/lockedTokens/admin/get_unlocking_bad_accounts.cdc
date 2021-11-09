

pub fun main(tokenAdmin: Address): {Address: UFix64} {

    let copyofDictionary: {Address: UFix64} = {}

    let account = getAccount(tokenAdmin)
    
    let dictionaryReference = account.getCapability<&{Address: UFix64}>(/public/unlockingBadAccounts).borrow()
        ?? panic("Could not get bad accounts dictionary")

    for address in dictionaryReference.keys {
        copyofDictionary[address] = dictionaryReference[address]!
    }

    return copyofDictionary
}