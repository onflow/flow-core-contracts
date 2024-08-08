import Test
import BlockchainHelpers
import "FlowDKG"

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "FlowDKG",
        path: "../contracts/epochs/FlowDKG.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun testInitialState_Disabled() {
    let scriptResult = executeScript(
        "../transactions/dkg/scripts/get_dkg_enabled.cdc",
        []
    )
    Test.expect(scriptResult, Test.beSucceeded())
    let enabled = scriptResult.returnValue! as! Bool
    Test.assertEqual(false, enabled)
}
