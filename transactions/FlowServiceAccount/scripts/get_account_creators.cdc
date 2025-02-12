import "FlowServiceAccount"

access(all) fun main(): [Address] {
    return FlowServiceAccount.getAccountCreators()
}