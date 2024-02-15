import FlowDKG from "FlowDKG"

access(all) fun main(fromIndex: Int): [FlowDKG.Message] {
    let messages = FlowDKG.getWhiteBoardMessages()
    var latestMessages: [FlowDKG.Message] = []
    var i = fromIndex
    while i < messages.length {
        latestMessages.append(messages[i])
        i = i + 1
    }
    return latestMessages
}