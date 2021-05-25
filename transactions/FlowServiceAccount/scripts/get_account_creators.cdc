import FlowServiceAccount from 0xFLOWSERVICEADDRESS

pub fun main(): [Address] {
    return FlowServiceAccount.getAccountCreators()
}