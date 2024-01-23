import Test
import BlockchainHelpers

pub fun setup() {
    Test.deployContract(name: "Burner", path: "../contracts/Burner.cdc", arguments: [])
    Test.deployContract(name: "BurnableTest", path: "../contracts/testContracts/BurnableTest.cdc", arguments: [])
}

pub fun testWithCallbackDestory_Allowed() {
    let acct = Test.createAccount()
     txExecutor(
        "burner/create_and_destroy_with_callback.cdc",
        [acct],
        [true]
    )
}

pub fun testWithCallback_NotAllowed() {
    let acct = Test.createAccount()

    Test.expectFailure(fun() {
        txExecutor(
            "burner/create_and_destroy_with_callback.cdc",
            [acct],
            [false]
        )
    }, errorMessageSubstring: "allowDestroy must be set to true")
}

pub fun testWithoutCallbackDestroy_Allowed() {
    let acct = Test.createAccount()
    txExecutor(
        "burner/create_and_destroy_without_callback.cdc",
        [acct],
        []
    )
}

pub fun testDestroy_Dict() {
    let acct = Test.createAccount()

    let types = [Type<Address>(), Type<String>(), Type<CapabilityPath>(), Type<Number>(), Type<Type>(), Type<Character>()]
    for type in types {
        txExecutor(
            "burner/create_and_destroy_dict.cdc",
            [acct],
            [true, type]
        ) 
    }
}

pub fun testDestroy_Dict_NotAllowed() {
    let acct = Test.createAccount()

    let types = [Type<Address>(), Type<String>(), Type<CapabilityPath>(), Type<Number>(), Type<Type>(), Type<Character>()]
    for type in types {
        Test.expectFailure(fun() {
            txExecutor(
                "burner/create_and_destroy_dict.cdc",
                [acct],
                [false, type]
            )
        }, errorMessageSubstring: "allowDestroy must be set to true")
    }
}

pub fun testDestroy_Array() {
    let acct = Test.createAccount()
    txExecutor(
        "burner/create_and_destroy_array.cdc",
        [acct],
        [true]
    )
}

pub fun loadCode(_ fileName: String, _ baseDirectory: String): String {
    return Test.readFile("./".concat(baseDirectory).concat("/").concat(fileName))
}

pub fun txExecutor(_ txName: String, _ signers: [Test.Account], _ arguments: [AnyStruct]): Test.TransactionResult {
    let txCode = loadCode(txName, "transactions")

    let authorizers: [Address] = []
    for signer in signers {
        authorizers.append(signer.address)
    }
    let tx = Test.Transaction(
        code: txCode,
        authorizers: authorizers,
        signers: signers,
        arguments: arguments,
    )
    let txResult = Test.executeTransaction(tx)
    if let err = txResult.error {
        panic(err.message)
    }
    return txResult
}