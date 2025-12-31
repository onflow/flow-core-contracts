import Test
import "RetrieveFraudulentTokensEvents"
import "EVM"
import "FlowToken"
import "FungibleToken"

access(all) let serviceAccount = Test.serviceAccount()
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "RetrieveFraudulentTokensEvents",
        path: "../contracts/testContracts/RetrieveFraudulentTokensEvents.cdc",
        arguments: []
    )

    Test.expect(err, Test.beNil())

    fundAccountWithFlow(to: admin.address, amount: 10000.0)

    setupCOATransaction(signer: admin, amount: 1000.0)
    depositToCOATransaction(signer: serviceAccount, amount: 1000.0)
}

access(all) fun testRetrieveCadenceTokens() {
    let cadenceAccounts: {Address: {String: UFix64}} = {
        admin.address: {
            "A.0000000000000003.FlowToken.Vault": 100.0
        }
    }

    retrieveCadenceTokens(accounts: cadenceAccounts)
}

access(all) fun testRetrieveCOATokens() {
    let coaAccounts: {Address: {String: UInt256}} = {
        admin.address: {
            "A.0000000000000003.FlowToken.Vault": 100000000000000000
        }
    }

    retrieveCOATokens(accounts: coaAccounts)
}

access(all) fun testRetrieveEOATokens() {
    let eoaAccounts: {String: UInt} = {
        "0x9D9247F5C3F3B78F7EE2C480B9CDaB91393Bf4D6": 100000000000000000
    }
    retrieveEOATokens(accounts: eoaAccounts)
}

access(all) fun retrieveCadenceTokens(accounts: {Address: {String: UFix64}}) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/FlowServiceAccount/retrieve_cadence_tokens_batch.cdc"),
        authorizers: [serviceAccount.address, admin.address],
        signers: [serviceAccount, admin],
        arguments: [accounts],
    )
    var result = Test.executeTransaction(tx)

    Test.expect(result, Test.beSucceeded())
}

access(all) fun retrieveCOATokens(accounts: {Address: {String: UInt256}}) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/FlowServiceAccount/retrieve_coa_tokens_batch.cdc"),
        authorizers: [serviceAccount.address, admin.address],
        signers: [serviceAccount, admin],
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

access(all) fun fundAccountWithFlow(to: Address, amount: UFix64) {

    var tx = Test.Transaction(
        code: Test.readFile("../transactions/flowToken/transfer_tokens.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [amount, to],
    )
    var result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())
}

access(all) fun setupCOATransaction(signer: Test.TestAccount, amount: UFix64) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/accounts/setup_coa.cdc"),
        authorizers: [signer.address],
        signers: [signer],
        arguments: [amount],
    )
    var result = Test.executeTransaction(tx)

    Test.expect(result, Test.beSucceeded())
}

access(all) fun depositToCOATransaction(signer: Test.TestAccount, amount: UFix64) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/accounts/deposit_to_coa.cdc"),
        authorizers: [signer.address],
        signers: [signer],
        arguments: [amount],
    )
    var result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())
}

