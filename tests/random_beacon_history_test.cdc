import Test
import BlockchainHelpers
import "RandomBeaconHistory"

access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "RandomBeaconHistory",
        path: "../contracts/RandomBeaconHistory.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testGetLowestHeightWhenNotInitialized() {
    let scriptResult = executeScript(
        "scripts/get_lowest_height.cdc",
        []
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "History has not yet been initialized"
    )
}

access(all)
fun testGetRandomSourceHistoryPageWithoutLowestHeightSet() {
    let page: UInt64 = 1
    let perPage: UInt64 = 10
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "History has not yet been initialized",
    )
}

access(all)
fun testGetSourceOfRandomnessWithoutLowestHeightSet() {
    let atBlockHeight: UInt64 = 101
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
        [atBlockHeight]
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "History has not yet been initialized"
    )
}

access(all)
fun testRecordRandomSource() {
    let randomSource: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    let txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [randomSource],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())

    let page: UInt64 = 0
    let perPage: UInt64 = 10
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.assertEqual(randomSource, history.values[0]!.value)
}

access(all)
fun testGetSourceOfRandomnessForMissingBlockHeight() {
    let atBlockHeight: UInt64 = 101
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
        [atBlockHeight]
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "Source of randomness not yet recorded"
    )
}

access(all)
fun testGetSourceOfRandomnessPrecedingRecordedHistory() {
    let lowestHeight = (executeScript(
        "scripts/get_lowest_height.cdc",
        []
    ).returnValue as! UInt64?)!
    let atBlockHeight: UInt64 = lowestHeight - 2

    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
        [atBlockHeight]
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "Requested block height precedes recorded history"
    )
}

access(all)
fun testGetSourceOfRandomnessFromPreviousBlockHeight() {
    // Commit current block and advance to the next one
    Test.commitBlock()

    let atBlockHeight: UInt64 = getCurrentBlockHeight() - 1
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
        [atBlockHeight]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let randomSource = scriptResult.returnValue! as! RandomBeaconHistory.RandomSource
    let value: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    Test.assertEqual(atBlockHeight, randomSource.blockHeight)
    Test.assertEqual(value, randomSource.value)
}

access(all)
fun testGetLatestSourceOfRandomness() {
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_latest_source_of_randomness.cdc",
        []
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let randomSource = scriptResult.returnValue! as! RandomBeaconHistory.RandomSource
    let atBlockHeight: UInt64 = getCurrentBlockHeight() - 1
    let value: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    Test.assertEqual(atBlockHeight, randomSource.blockHeight)
    Test.assertEqual(value, randomSource.value)
}

access(all)
fun testGetRandomSourceHistoryPageExceedingLastPage() {
    // There is only 1 page currently
    let page: UInt64 = 11
    let perPage: UInt64 = 10
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.expect(history.values, Test.beEmpty())
}
