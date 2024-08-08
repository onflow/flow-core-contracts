import Test
import BlockchainHelpers

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
}

access(all)
fun testCreateAccount() {
    let key = "7d5305c22cb7da418396f32c474c6d84b0bb87ca311d6aa6edfd70a1120ded9dc11427ac31261c24e4e7a6c2affea28ff3da7b00fe285029877fb0b5970dc110"
    
    // Should fail
    var txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(0), UInt8(1), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a signature algorithm raw value that is 1, 2, or 3"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(5), UInt8(1), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a signature algorithm raw value that is 1, 2, or 3"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(0), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a hash algorithm raw value that is between 1 and 6"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(10), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a hash algorithm raw value that is between 1 and 6"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(1), 1222100.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "The key weight must be between 0 and 1000"
    )

    // Should succeed
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(1), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun testAddKey() {
    let key = "7d5305c22cb7da418396f32c474c6d84b0bb87ca311d6aa6edfd70a1120ded9dc11427ac31261c24e4e7a6c2affea28ff3da7b00fe285029877fb0b5970dc110"
    
    // Should fail
    var txResult = executeTransaction(
        "../transactions/accounts/add_key.cdc",
        [key, UInt8(0), UInt8(1), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a signature algorithm raw value that is 1, 2, or 3"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/add_key.cdc",
        [key, UInt8(5), UInt8(1), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a signature algorithm raw value that is 1, 2, or 3"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/add_key.cdc",
        [key, UInt8(1), UInt8(0), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a hash algorithm raw value that is between 1 and 6"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/add_key.cdc",
        [key, UInt8(1), UInt8(10), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Must provide a hash algorithm raw value that is between 1 and 6"
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/add_key.cdc",
        [key, UInt8(1), UInt8(1), 1222100.0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "The key weight must be between 0 and 1000"
    )

    // Should succeed
    txResult = executeTransaction(
        "../transactions/accounts/add_key.cdc",
        [key, UInt8(1), UInt8(1), 1000.0],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun testRevokeKey() {

    // Should fail because no key with that index exists
    var txResult = executeTransaction(
        "../transactions/accounts/revoke_key.cdc",
        [8],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "No key with the given index exists on the authorizer's account"
    )

    // Should succeed
    txResult = executeTransaction(
        "../transactions/accounts/revoke_key.cdc",
        [1],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
}