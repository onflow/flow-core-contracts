import Test
import BlockchainHelpers

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
        [key, UInt8(0), UInt8(1)],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Cannot add Key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided 0")
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
    )
     
    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(3), UInt8(1)],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Cannot add Key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided 3")
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(0)],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Cannot add Key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided 0")
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
    )

    // Should fail
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(2)],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Cannot add Key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided 2")
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
    )

    // Should succeed
    txResult = executeTransaction(
        "../transactions/accounts/create_new_account.cdc",
        [key, UInt8(1), UInt8(1)],
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
        errorMessage: "Cannot add Key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided 0")
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
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
        errorMessage: "Cannot add Key: Must provide a signature algorithm raw value that corresponds to "
                .concat("one of the available signature algorithms for Flow keys.")
                .concat("You provided 5")
                .concat(" but the options are either 1 (ECDSA_P256) or 2 (ECDSA_secp256k1).")
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
        errorMessage: "Cannot add Key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided 0")
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
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
        errorMessage: "Cannot add Key: Must provide a hash algorithm raw value that corresponds to "
                .concat("one of of the available hash algorithms for Flow keys.")
                .concat("You provided 10")
                .concat(" but the options are either 1 (SHA2_256) or 3 (SHA3_256).")
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
        errorMessage: "Cannot add Key: The key weight must be between 0 and 1000."
                .concat(" You provided 1222100.00000000 which is invalid.")
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
        errorMessage: "Cannot revoke key: No key with the index 8"
                .concat(" exists on the authorizer's account.")
    )

    // Should succeed
    txResult = executeTransaction(
        "../transactions/accounts/revoke_key.cdc",
        [1],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
}