import FlowServiceAccount from 0xFLOWSERVICEADDRESS

pub fun main(address: Address): Bool {
    return FlowServiceAccount.isAccountCreator(address)
}