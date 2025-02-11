import "FlowDKG"

access(all) fun main(): [FlowDKG.ResultSubmission] {
    return FlowDKG.getFinalSubmissions()
}