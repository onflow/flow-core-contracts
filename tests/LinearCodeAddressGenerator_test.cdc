import Test
import "LinearCodeAddressGenerator"

access(all)
fun setup() {
    var err: Test.Error? = Test.deployContract(
        name: "LinearCodeAddressGenerator",
        path: "../contracts/LinearCodeAddressGenerator.cdc",
        arguments: [],
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun generateAddresses(
    count: UInt64,
    chainCodeWord: UInt64
): [Address] {
    let addresses: [Address] = []
    for index in InclusiveRange<UInt64>(1, count) {
        let address = LinearCodeAddressGenerator.address(
            at: index,
            chainCodeWord: chainCodeWord
        )
        addresses.append(address)
    }

    return addresses
}

access(all)
fun checkAddresses(
    count: UInt64,
    chainCodeWord: UInt64,
    expected: [Address]
) {
     let actual = generateAddresses(
        count: 10,
        chainCodeWord: chainCodeWord
    )

    Test.assertEqual(expected, actual)

    for address in actual {
        Test.assert(
            LinearCodeAddressGenerator.isValidAddress(
                address,
                chainCodeWord: chainCodeWord
            )
        )
    }
}

access(all)
fun testMainnet() {
    checkAddresses(
        count: 10,
        chainCodeWord: LinearCodeAddressGenerator.codeWordMainnet,
        expected: [
            0xe467b9dd11fa00df,
            0xf233dcee88fe0abe,
            0x1654653399040a61,
            0xf919ee77447b7497,
            0x1d7e57aa55817448,
            0x0b2a3299cc857e29,
            0xef4d8b44dd7f7ef6,
            0xfc8cf73ba23a260d,
            0x18eb4ee6b3c026d2,
            0x0ebf2bd52ac42cb3
        ]
    )
}

access(all)
fun testTestnet() {
    checkAddresses(
        count: 10,
        chainCodeWord: LinearCodeAddressGenerator.codeWordTestnet,
        expected: [
            0x8c5303eaa26202d6,
            0x9a0766d93b6608b7,
            0x7e60df042a9c0868,
            0x912d5440f7e3769e,
            0x754aed9de6197641,
            0x631e88ae7f1d7c20,
            0x877931736ee77cff,
            0x94b84d0c11a22404,
            0x70dff4d1005824db,
            0x668b91e2995c2eba
        ]
    )
}

access(all)
fun testTransient() {
    checkAddresses(
        count: 10,
        chainCodeWord: LinearCodeAddressGenerator.codeWordTransient,
        expected: [
            0xf8d6e0586b0a20c7,
            0xee82856bf20e2aa6,
            0x0ae53cb6e3f42a79,
            0xe5a8b7f23e8b548f,
            0x01cf0e2f2f715450,
            0x179b6b1cb6755e31,
            0xf3fcd2c1a78f5eee,
            0xe03daebed8ca0615,
            0x045a1763c93006ca,
            0x120e725050340cab
        ]
    )
}
