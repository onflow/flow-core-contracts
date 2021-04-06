import FlowDKG from 0xDKGADDRESS

pub fun main(fromIndex: Int): [FlowDKG.Message] {
    let messages = FlowDKG.getWhiteBoardMessages()

    var latestMessages: [FlowDKG.Message] = []

    if fromIndex >= messages.length {
        panic("Index out of range for DKG whiteboard messages array")
    } else {

        var i = fromIndex

        while i < messages.length {
            latestMessages.append(messages[i])

            i = i + 1
        }
    }

    return latestMessages
}