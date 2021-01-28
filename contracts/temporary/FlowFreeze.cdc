/*

    FlowFreeze

    This contract gives an admin the ability to freeze/unfreeze accounts
    by adding them to a list stored in the contract.

    If the account is on the frozen list, it will not be able to send transactions
    and any transaction that accesses its account state will fail.

    The execution envorionment will automatically query this contract as part of every transaction.

    This is a TEMPORARY CONTRACT that will be in place until the proper protections
    are in place with fees and the network is more decentralized

 */


pub contract FlowFreeze {

    access(account) var freezeList: {Address: Bool}

    pub let AdminStoragePath: StoragePath

    pub resource Admin {

        pub fun freezeAccount(_ address: Address) {
            FlowFreeze.freezeList[address] = true
        }

        pub fun unfreezeAccount(_ address: Address) {
            FlowFreeze.freezeList[address] = nil
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