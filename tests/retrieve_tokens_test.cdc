import Test
import "RetrieveFraudulentTokensEvents"
import "EVM"
import "FlowToken"
import "FungibleToken"

access(all) let serviceAccount = Test.serviceAccount()

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "RetrieveFraudulentTokensEvents",
        path: "../contracts/testContracts/RetrieveFraudulentTokensEvents.cdc",
        arguments: []
    )

    Test.expect(err, Test.beNil())
}

access(all)
fun testRetrieveTokensEvents() {
    let cadenceAccounts: {Address: {String: UFix64}} = {
        serviceAccount.address: {
            "A.1654653399040a61.FlowToken.Vault": 100.0
        }
    }

    retrieveCadenceTokens(accounts: cadenceAccounts)

    let coaAccounts: {Address: {String: UFix64}} = {
        serviceAccount.address: {
            "A.1654653399040a61.FlowToken.Vault": 100.0
        }
    }

    retrieveCOATokens(accounts: coaAccounts)

    let eoaAccounts: {String: UInt} = {
        "0x9D9247F5C3F3B78F7EE2C480B9CDaB91393Bf4D6": 100000000000000000
    }
    retrieveEOATokens(accounts: eoaAccounts)
}

access(all) fun retrieveCadenceTokens(accounts: {Address: {String: UFix64}}) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/FlowServiceAccount/retrieve_cadence_tokens_batch.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [accounts],
    )
    var result = Test.executeTransaction(tx)

    Test.expect(result, Test.beSucceeded())
}

access(all) fun retrieveCOATokens(accounts: {Address: {String: UFix64}}) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/FlowServiceAccount/retrieve_coa_tokens_batch.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [accounts],
    )
    var result = Test.executeTransaction(tx)

    Test.expect(result, Test.beSucceeded())
}

access(all) fun retrieveEOATokens(accounts: {String: UInt}) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/FlowServiceAccount/retrieve_eoa_tokens_batch.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [accounts],
    )
    var result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())
}



