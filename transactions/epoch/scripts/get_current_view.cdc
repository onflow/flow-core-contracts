// Returns the view of the current block

pub fun main(): UInt64 {
    let currentBlock = getCurrentBlock()
    return currentBlock.view
}