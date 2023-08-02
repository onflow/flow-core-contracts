import FlowServiceAccount from 0xFLOWSERVICEADDRESS

access(all) fun main(): [Address] {
    return FlowServiceAccount.getAccountCreators()
}