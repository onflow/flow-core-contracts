import FlowServiceAccount from 0xSERVICEADDRESS

pub fun main(): [Address] {
    return FlowServiceAccount.getAccountCreators()
}