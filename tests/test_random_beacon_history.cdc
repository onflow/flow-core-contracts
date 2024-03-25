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
    let atBlockHeight: UInt64 = getCurrentBlockHeight() + 10
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

// At this point the history array is empty
access(all)
fun testRecordRandomSource() {
    let randomSource: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    // executeTransaction advances the block height then executes the transaction! 
    let txResult = executeTransaction(   
        "transactions/record_random_source.cdc",
        [randomSource],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
}

// At this point the history array has 1 entry
access(all)
fun testGetSourceOfRandomnessForFutureBlockHeight() {
    // random source entry of the current block height must be only available
    // starting from the next block height
    let atBlockHeight: UInt64 = getCurrentBlockHeight()
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

// At this point the history array has 1 entry
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

// At this point the history array has 1 entry
access(all)
fun testGetRecordedSourceOfRandomnessPage() {
    let page: UInt64 = 0
    let perPage: UInt64 = 10
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.assertEqual(page, history.page)
    Test.assertEqual(perPage, history.perPage)
    Test.assertEqual(UInt64(1), history.totalLength)
    Test.assertEqual(1, history.values.length)
    let value: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    Test.assertEqual(value, history.values[0]!.value)
}

// At this point the history array has 1 entry
access(all)
fun testGetRecordedSourceOfRandomness() {
    // record a new random source and advance to the next block,
    // this way the previous block's entry becomes available
    let value: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    let txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [value],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())

    let atBlockHeight: UInt64 = getCurrentBlockHeight() - 1
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
        [atBlockHeight]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let randomSource = scriptResult.returnValue! as! RandomBeaconHistory.RandomSource
    Test.assertEqual(atBlockHeight, randomSource.blockHeight)
    Test.assertEqual(value, randomSource.value)
}

// At this point the history array has 2 entries
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


// At this point the history array has 2 entries
access(all)
fun testGetMissingSourceFromGap() {
    // advance blocks without recording a random source, hence creating a gap
    // in the history array.
    // So far only two entry were recorded
    let gapLength = UInt64(90)
    var i = UInt64(0)
    while i < gapLength {   
        Test.commitBlock()
        i = i + 1
    }

    // sources in the gap are non recorded and must be backfilled later
    let gapStartIndex = RandomBeaconHistory.getLowestHeight() + 2 // skip the 2 recorded entries

    i = 0
    while i < gapLength-1 {
        let atBlockHeight = gapStartIndex + i 
        let scriptResult = executeScript(
            "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
            [atBlockHeight]
        )
        Test.expect(scriptResult, Test.beFailed())
        Test.assertError(
            scriptResult,
            errorMessage: "Source of randomness is currently not available but will be available soon"
        )
        i = i + 1
    }
}

// At this point the history array has 2 entries and then an empty gap
access(all)
fun testGetPageFromGap() {
    // So far only two entry were recorded and then there is a gap
    // the page function only returns the SoRs recorded so far which are limited to the 2 entries
    let recordedSurces = 2

    let page: UInt64 = 0
    let perPage: UInt64 = 4
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.assertEqual(page, history.page)
    Test.assertEqual(perPage, history.perPage)
    Test.assertEqual(UInt64(recordedSurces), history.totalLength)
    Test.assertEqual(recordedSurces, history.values.length)
    let value: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    Test.assertEqual(value, history.values[0]!.value)
}


// at this point the history has 2 entries and then a gap
access(all)
fun testGetBackfilledSource() {
    let gapLength = UInt64(90)  // matching the length from the previous test

    // record a new random source, which would trigger fully backfilling the gap 
    // (when the gap size is less than 100, since the contracts backfills up to 100 entries at a time)
    assert(gapLength <= 100)
    var value: [UInt8] = [0, 1, 1, 2, 3, 5, 8] 
    let txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [value],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())

    // make sure latest source got recorded as exptected
    Test.commitBlock()
    let atBlockHeight: UInt64 = getCurrentBlockHeight() - 1
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
        [atBlockHeight]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let randomSource = scriptResult.returnValue! as! RandomBeaconHistory.RandomSource
    Test.assertEqual(atBlockHeight, randomSource.blockHeight)
    Test.assertEqual(value, randomSource.value)

    // check the gap and makes sure it got backfilled
    let gapStartIndex = RandomBeaconHistory.getLowestHeight() + 2 // skip the 2 recorded entries
    var i = UInt64(0)
    while i < gapLength {
        let atBlockHeight = gapStartIndex + i
        let scriptResult = executeScript(
            "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
            [atBlockHeight]
        )
        Test.expect(scriptResult, Test.beSucceeded())

        let randomSource = scriptResult.returnValue! as! RandomBeaconHistory.RandomSource
        Test.assertEqual(atBlockHeight, randomSource.blockHeight)
        // compare against the expected backfilled value
        value = HashAlgorithm.SHA3_256.hash(value)
        Test.assertEqual(value, randomSource.value)
        i = i + 1
    }
}

// At this point the history array has 2+90+1 = 93 entries and no gaps
access(all)
fun testGetPageAfterBackfilling() {
    // So far only two entry were recorded and then there is a gap
    // the page function only returns the SoRs recorded so far which are limited to the 2 entries
    let recordedSurces = UInt64(93)

    let page: UInt64 = 5
    let perPage: UInt64 = 10
    assert((page+1) * perPage < recordedSurces)
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.assertEqual(page, history.page)
    Test.assertEqual(perPage, history.perPage)
    Test.assertEqual(recordedSurces, history.totalLength)
    Test.assertEqual(perPage, UInt64(history.values.length))
}