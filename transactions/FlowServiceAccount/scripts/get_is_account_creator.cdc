import FlowServiceAccount from 0xFLOWSERVICEADDRESS

access(all) fun main(address: Address): Bool {
    return FlowServiceAccount.isAccountCreator(address)
}