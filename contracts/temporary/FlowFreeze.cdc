/*

    FlowFreeze

    This contract gives an admin the ability to freeze/unfreeze accounts
    by adding them to a list stored in the contract.

    If the account is on the frozen list, it will not be able to send transactions
    and any transaction that accesses its account state will fail.

    The `setAccountFrozen` function is a global function that can only be called
    by the service account, which marks an account in the FVM to be frozen.

    The contract is to allow for transparency.

    This is a TEMPORARY CONTRACT that will be in place until the proper protections
    are in place with fees and the network is more decentralized

 */


pub contract FlowFreeze {

    pub event AccountFrozen(_ address: Address)
    pub event AccountUnfrozen(_ address: Address)

    access(account) var freezeList: {Address: Bool}

    pub let AdminStoragePath: StoragePath

    pub resource Admin {

        pub fun freezeAccount(_ address: Address) {
            FlowFreeze.freezeList[address] = true
            setAccountFrozen(address, true)
            emit AccountFrozen(address)
        }

        pub fun unfreezeAccount(_ address: Address) {
            FlowFreeze.freezeList.remove(key: address)
            setAccountFrozen(address, false)
            emit AccountUnfrozen(address)
        }
    }

    pub fun getFreezeList(): {Address: Bool} {
        return FlowFreeze.freezeList
    }

    init() {
        self.freezeList = {}
        self.AdminStoragePath = /storage/flowFreezeAdmin

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
    
}