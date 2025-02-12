import "FlowDKG"

access(all) fun main(): Bool {
    return FlowDKG.dkgCompleted() != nil
}