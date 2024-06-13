// Returns the view of the current block

access(all) fun main(): UInt64 {
    let currentBlock = getCurrentBlock()
    return currentBlock.view
}
