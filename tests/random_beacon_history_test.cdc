import Test
import BlockchainHelpers
import "RandomBeaconHistory"

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)
access(all) let defaultBackfillerMax = UInt64(100)

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
    let randomSource: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8]
    // executeTransaction advances the block height then executes the transaction! 
    let txResult = executeTransaction(   
        "transactions/record_random_source.cdc",
        [randomSource],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
    // get backfiller max entries 
    let scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_backfiller_max_entries.cdc",
        [admin.address]
    )
    Test.expect(scriptResult, Test.beSucceeded())
    let resultBackfillerMax = scriptResult.returnValue! as! UInt64
    Test.assertEqual(defaultBackfillerMax, resultBackfillerMax)
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
    let value: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8]
    Test.assertEqual(value, history.values[0]!.value)
}

// At this point the history array has 1 entry
access(all)
fun testGetRecordedSourceOfRandomness() {
    // record a new random source and advance to the next block,
    // this way the previous block's entry becomes available
    let value: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8]
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
    let value: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8]
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
    let value: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8]
    Test.assertEqual(value, history.values[0]!.value)
}


// at this point the history has 2 entries and then a gap
access(all)
fun testGetBackfilledSource() {
    let gapLength = UInt64(90)  // matching the length from the previous test

    // record a new random source, which would trigger fully backfilling the gap 
    // (when the gap size is less than 100, since the contracts backfills up to 100 entries at a time)
    assert(gapLength <= defaultBackfillerMax)
    var value: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8] 
    let txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [value],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())

    // make sure latest source got recorded as expected
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
     

    // check the gap and make sure it got backfilled
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

    // Confirm event values
    let missingEvents = Test.eventsOfType(Type<RandomBeaconHistory.RandomHistoryMissing>())
    Test.assertEqual(1, missingEvents.length)
    let missingEvent = missingEvents[0] as! RandomBeaconHistory.RandomHistoryMissing
    Test.assertEqual(atBlockHeight, missingEvent.blockHeight)
    Test.assertEqual(gapStartHeight, missingEvent.gapStartHeight)

    let backfilledEvents = Test.eventsOfType(Type<RandomBeaconHistory.RandomHistoryBackfilled>())
    Test.assertEqual(1, backfilledEvents.length)
    let backfilledEvent = backfilledEvents[0] as! RandomBeaconHistory.RandomHistoryBackfilled
    Test.assertEqual(atBlockHeight, backfilledEvent.blockHeight)
    Test.assertEqual(gapStartHeight, backfilledEvent.gapStartHeight)
    Test.assertEqual(gapLength, backfilledEvent.count)
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
fun testNonContiguousGaps() {
    Test.reset(to: RandomBeaconHistory.getLowestHeight())

    // advance blocks without recording a random source, hence creating a gap
    // in the history array. The gap is long enough so that it can't be backfilled
    // in one transaction only (gap is larger than 100)
    var gapLength = UInt64(120)
    assert (gapLength > defaultBackfillerMax)
    var i = UInt64(0)
    while i < gapLength {   
        Test.commitBlock()
        i = i + 1
    }

    // record a new random source, which would trigger partially backfilling the gap 
    // (when the gap size is more than 100, since the contracts backfills up to 100 entries at a time)
    var value: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8] 
    var txResult = executeTransaction(
        "transactions/record_random_source.cdc",
        [value],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
    var backfillingHeight = getCurrentBlockHeight()

    // the gap is partially backfilled
    // for `gapStartHeight` skip the 1 recorded entry and backfilled entries
    var gapStartHeight = RandomBeaconHistory.getLowestHeight() + defaultBackfillerMax + 1
    // the remaining gap after backfilling
    gapLength = gapLength - defaultBackfillerMax

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
    var perPage: UInt64 = defaultBackfillerMax + 5 // 5 entries are empty on the SoR array
    var scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_source_of_randomness_page.cdc",
        [page, perPage]
    )
    Test.expect(scriptResult, Test.beFailed())
    Test.assertError(
        scriptResult,
        errorMessage: "Source of randomness is currently not available but will be available soon"
    )

    // Confirm event values
    // There should be one event of each type
    var missingEvents = Test.eventsOfType(Type<RandomBeaconHistory.RandomHistoryMissing>())
    Test.assertEqual(1, missingEvents.length)
    var missingEvent = missingEvents[0] as! RandomBeaconHistory.RandomHistoryMissing
    Test.assertEqual(backfillingHeight, missingEvent.blockHeight)
    Test.assertEqual(gapStartHeight - defaultBackfillerMax, missingEvent.gapStartHeight)

    var backfilledEvents = Test.eventsOfType(Type<RandomBeaconHistory.RandomHistoryBackfilled>())
    Test.assertEqual(1, backfilledEvents.length)
    var backfilledEvent = backfilledEvents[0] as! RandomBeaconHistory.RandomHistoryBackfilled
    Test.assertEqual(backfillingHeight, backfilledEvent.blockHeight)
    Test.assertEqual(gapStartHeight- defaultBackfillerMax, backfilledEvent.gapStartHeight)
    Test.assertEqual(defaultBackfillerMax, backfilledEvent.count)

    // insert a new gap and make sure it can be all backfilled in the next transaction
    var newGapLength = UInt64(20)
    assert (gapLength + newGapLength < defaultBackfillerMax)

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
    backfillingHeight = getCurrentBlockHeight()

    // check that both first and second gap are backfilled
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

    // Confirm event values

    // There should be two events of each type
    // the first events were already checked above - focus only on the second event of each type
    missingEvents = Test.eventsOfType(Type<RandomBeaconHistory.RandomHistoryMissing>())
    Test.assertEqual(2, missingEvents.length)
    missingEvent = missingEvents[1] as! RandomBeaconHistory.RandomHistoryMissing
    Test.assertEqual(backfillingHeight, missingEvent.blockHeight)
    Test.assertEqual(gapStartHeight, missingEvent.gapStartHeight)
    
    backfilledEvents = Test.eventsOfType(Type<RandomBeaconHistory.RandomHistoryBackfilled>())
    Test.assertEqual(2, backfilledEvents.length)
    backfilledEvent = backfilledEvents[1] as! RandomBeaconHistory.RandomHistoryBackfilled
    Test.assertEqual(backfillingHeight, backfilledEvent.blockHeight)
    Test.assertEqual(gapStartHeight - gapLength - 1, backfilledEvent.gapStartHeight)
    Test.assertEqual(gapLength + newGapLength, backfilledEvent.count)
}

// independent test from the rest (it resets the blockchain state)
access(all)
fun testRecordInvalidRandomSource() {
    // reset the blockchain state back to the lowest height (1 SoR entry)
    Test.reset(to: RandomBeaconHistory.getLowestHeight())

    let invalidRandomSource: [UInt8] = [0, 1, 1, 2, 3, 5, 8]
    assert (invalidRandomSource.length < (128/8))
    // short sources should be rejected
    let txResult = executeTransaction(   
        "transactions/record_random_source.cdc",
        [invalidRandomSource],
        admin
    )
    Test.expect(txResult, Test.beFailed())
    Test.assertError(
        txResult,
        errorMessage: "Random source must be at least 128 bits"
    )
}

// independent test from the rest (it resets the blockchain state)
access(all)
fun testBackfillerMaxEntryPerCall() {
    // reset the blockchain state back to the lowest height (1 SoR entry)
    Test.reset(to: RandomBeaconHistory.getLowestHeight())
    // get backfiller max entries 
    var scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_backfiller_max_entries.cdc",
        [admin.address]
    )
    Test.expect(scriptResult, Test.beSucceeded())
    var resultBackfillerMax = scriptResult.returnValue! as! UInt64
    Test.assertEqual(defaultBackfillerMax, resultBackfillerMax)

    let randomSource: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 5, 8] 
    // this creates a backfiller
    var txResult = executeTransaction(   
        "transactions/record_random_source.cdc",
        [randomSource],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
    // set backfiller max entries
    let newBackfillerMax = UInt64(55) 
    txResult = executeTransaction(   
        "../transactions/randomBeaconHistory/transactions/set_backfiller_max_entries.cdc",
        [newBackfillerMax],
        admin
    )
    Test.expect(txResult, Test.beSucceeded())
    // get backfiller max entries 
    scriptResult = executeScript(
        "../transactions/randomBeaconHistory/scripts/get_backfiller_max_entries.cdc",
        [admin.address]
    )
    Test.expect(scriptResult, Test.beSucceeded())
    resultBackfillerMax = scriptResult.returnValue! as! UInt64
    Test.assertEqual(resultBackfillerMax!, newBackfillerMax)
    // invalid backfiller max entries
    txResult = executeTransaction(   
        "../transactions/randomBeaconHistory/transactions/set_backfiller_max_entries.cdc",
        [0],
        admin
    )
    Test.expect(txResult, Test.beFailed())
}
