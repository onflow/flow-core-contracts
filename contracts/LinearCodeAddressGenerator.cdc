
/// LinearCodeAddressGenerator allows generating and validating Flow account addresses.
access(all)
contract LinearCodeAddressGenerator {

    access(all)
    enum Chain: UInt8 {
        access(all)
        case Mainnet

        access(all)
        case Testnet

        access(all)
        case Transient
    }

    /// Rows of the generator matrix G of the [64,45]-code used for Flow addresses.
    /// G is a (k x n) matrix with coefficients in GF(2), each row is converted into
    /// a big endian integer representation of the GF(2) raw vector.
    /// G is used to generate the account addresses
    access(self)
    let generatorMatrixRows: [UInt64; 45]

    /// Columns of the parity-check matrix H of the [64,45]-code used for Flow addresses.
    /// H is a (n x p) matrix with coefficients in GF(2), each column is converted into
    /// a big endian integer representation of the GF(2) column vector.
    /// H is used to verify a code word is a valid account address.
    access(self)
    let parityCheckMatrixColumns: [UInt64; 64]

    init() {
        self.generatorMatrixRows = [
            0xe467b9dd11fa00df, 0xf233dcee88fe0abe, 0xf919ee77447b7497, 0xfc8cf73ba23a260d,
            0xfe467b9dd11ee2a1, 0xff233dcee888d807, 0xff919ee774476ce6, 0x7fc8cf73ba231d10,
            0x3fe467b9dd11b183, 0x1ff233dcee8f96d6, 0x8ff919ee774757ba, 0x47fc8cf73ba2b331,
            0x23fe467b9dd27f6c, 0x11ff233dceee8e82, 0x88ff919ee775dd8f, 0x447fc8cf73b905e4,
            0xa23fe467b9de0d83, 0xd11ff233dce8d5a7, 0xe88ff919ee73c38a, 0x7447fc8cf73f171f,
            0xba23fe467b9dcb2b, 0xdd11ff233dcb0cb4, 0xee88ff919ee26c5d, 0x77447fc8cf775dd3,
            0x3ba23fe467b9b5a1, 0x9dd11ff233d9117a, 0xcee88ff919efa640, 0xe77447fc8cf3e297,
            0x73ba23fe467fabd2, 0xb9dd11ff233fb16c, 0xdcee88ff919adde7, 0xee77447fc8ceb196,
            0xf73ba23fe4621cd0, 0x7b9dd11ff2379ac3, 0x3dcee88ff91df46c, 0x9ee77447fc88e702,
            0xcf73ba23fe4131b6, 0x67b9dd11ff240f9a, 0x33dcee88ff90f9e0, 0x19ee77447fcff4e3,
            0x8cf73ba23fe64091, 0x467b9dd11ff115c7, 0x233dcee88ffdb735, 0x919ee77447fe2309,
            0xc8cf73ba23fdc736
        ]

        self.parityCheckMatrixColumns = [
            0x00001, 0x00002, 0x00004, 0x00008, 0x00010, 0x00020, 0x00040, 0x00080,
            0x00100, 0x00200, 0x00400, 0x00800, 0x01000, 0x02000, 0x04000, 0x08000,
            0x10000, 0x20000, 0x40000, 0x7328d, 0x6689a, 0x6112f, 0x6084b, 0x433fd,
            0x42aab, 0x41951, 0x233ce, 0x22a81, 0x21948, 0x1ef60, 0x1deca, 0x1c639,
            0x1bdd8, 0x1a535, 0x194ac, 0x18c46, 0x1632b, 0x1529b, 0x14a43, 0x13184,
            0x12942, 0x118c1, 0x0f812, 0x0e027, 0x0d00e, 0x0c83c, 0x0b01d, 0x0a831,
            0x0982b, 0x07034, 0x0682a, 0x05819, 0x03807, 0x007d2, 0x00727, 0x0068e,
            0x0067c, 0x0059d, 0x004eb, 0x003b4, 0x0036a, 0x002d9, 0x001c7, 0x0003f
        ]
    }

    access(self)
    fun codeWord(forChain chain: Chain): UInt64 {
    	switch chain {
        case Chain.Mainnet:
            return 0
        case Chain.Testnet:
            return 0x6834ba37b3980209
        case Chain.Transient:
            return 0x1cb159857af02018
        default:
            panic("unsupported chain")
        }
    }

    access(self)
    fun encodeWord(_ word: UInt64): UInt64 {

    	// Multiply the index GF(2) vector by the code generator matrix

        var codeWord: UInt64 = 0
        var word = word

        for generatorMatrixRow in self.generatorMatrixRows {
            if word & 1 == 1 {
                codeWord = codeWord ^ generatorMatrixRow
            }
            word = word >> 1
        }

        return codeWord
    }

    /// Returns the address at the given index, for the given chain.
    access(all)
    fun address(at index: UInt64, chain: Chain): Address {
        return Address(self.encodeWord(index) ^ self.codeWord(forChain: chain))
    }

    /// Returns true if the given address is valid, for the given chain code word.
    access(all)
    fun isValidAddress(_ address: Address, chain: Chain): Bool {

        let address = UInt64.fromBigEndianBytes(address.toBytes())!
        var codeWord = self.codeWord(forChain: chain) ^ address

        if codeWord == 0 {
            return false
        }

    	// Multiply the code word GF(2)-vector by the parity-check matrix

        var parity: UInt64 = 0

        for parityCheckMatrixColumn in self.parityCheckMatrixColumns {
            if codeWord & 1 == 1 {
                parity = parity ^ parityCheckMatrixColumn
            }
            codeWord = codeWord >> 1
        }

        return parity == 0 && codeWord == 0
    }
}
