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
    let gapStartHeight = RandomBeaconHistory.getLowestHeight() + 2 // skip the 2 recorded entries

    i = 0
    while i < gapLength-1 {
        let atBlockHeight = gapStartHeight + i 
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
    let recordedSources = 2

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
    Test.assertEqual(UInt64(recordedSources), history.totalLength)
    Test.assertEqual(recordedSources, history.values.length)
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
    let gapStartHeight = RandomBeaconHistory.getLowestHeight() + 2 // skip the 2 recorded entries
    var i = UInt64(0)
    while i < gapLength {
        let atBlockHeight = gapStartHeight + i
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
    let recordedSources = UInt64(93)

    let page: UInt64 = 5
    let perPage: UInt64 = 10
    assert((page+1) * perPage < recordedSources)
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.assertEqual(page, history.page)
    Test.assertEqual(perPage, history.perPage)
    Test.assertEqual(recordedSources, history.totalLength)
    Test.assertEqual(perPage, UInt64(history.values.length))
}

// reset the blockchain state back to the lowest height (1 SoR entry)
//
// The next section tests an edge case where a gap is not contiguous. This happens
// when an initial large gap doesn't get fully backfilled before another gap occurs.
access(all)
fun testNonContiguousGap() {
    Test.reset(to: RandomBeaconHistory.getLowestHeight())

    // advance blocks without recording a random source, hence creating a gap
    // in the history array. The gap is long enough so that it can't be backfilled
    // in one transaction only (gap is larger than 100)
    var gapLength = UInt64(120)
    assert (gapLength > 100)
    var i = UInt64(0)
    while i < gapLength {   
        Test.commitBlock()
        i = i + 1
    }

    // record a new random source, which would trigger partially backfilling the gap 
    // (when the gap size is more than 100, since the contracts backfills up to 100 entries at a time)
    var value: [UInt8] = [0, 1, 1, 2, 3, 5, 8] 
    var txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [value],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())

    // the gap is partially backfilled
    // for `gapStartHeight` skip the 1 recorded entry and backfilled entries
    var gapStartHeight = RandomBeaconHistory.getLowestHeight() + 100 + 1 
    // the remaining gap after backfilling
    gapLength = gapLength - 100

    // check that the gap isn't fully backfilled
    // (check that the gap got backfilled was covered by an earlier test)
    i = 0
    while i < gapLength {
        let atBlockHeight = gapStartHeight + i 
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

    // check that getting pages also fails in this case
    // because some entries are missing from the page
    var page: UInt64 = 0
    var perPage: UInt64 = 100 + 5 // 5 entries are empty on the SoR array
    var scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "Source of randomness is currently not available but will be available soon"
    )

    // insert a new gap and make sure it can be all backfilled in the next transction
    var newGapLength = UInt64(20)
    assert (gapLength + newGapLength < 100)

    i = UInt64(0)
    while i < newGapLength {   
        Test.commitBlock()
        i = i + 1
    }

    // at this point there is a gap of size `gapLength` followed by one entry, and then
    // a new gap of size `newGapLength`
    // one call to the heartbeat function should backfill both gaps
    txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [value],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())

    // check that both first and second gaps are not backfilled
    i = 0
    while i < gapLength {
        let atBlockHeight = gapStartHeight + i
        let scriptResult = executeScript(
            "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
            [atBlockHeight]
        )
        Test.expect(scriptResult, Test.beSucceeded())
        i = i + 1
    }
    gapStartHeight = gapStartHeight + gapLength + 1
    i = 0
    while i < newGapLength {
        let atBlockHeight = gapStartHeight + i
        let scriptResult = executeScript(
            "../transactions/randomBeaconHistory/scripts/get_source_of_randomness.cdc",
            [atBlockHeight]
        )
        Test.expect(scriptResult, Test.beSucceeded())
        i = i + 1
    }

    // check getting a page with the entire history succeeds,
    // which means no entry got left empty. 
    let totalSources = gapStartHeight + newGapLength + 1 - RandomBeaconHistory.getLowestHeight()

    page = 0
    perPage = totalSources
    scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beSucceeded())

    let history = (scriptResult.returnValue as! RandomBeaconHistory.RandomSourceHistoryPage?)!
    Test.assertEqual(page, history.page)
    Test.assertEqual(perPage, history.perPage)
    Test.assertEqual(totalSources, history.totalLength)
    Test.assertEqual(perPage, UInt64(history.values.length))
}