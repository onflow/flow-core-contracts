import FlowServiceAccount from "FlowServiceAccount"

access(all) fun main(): [Address] {
    return FlowServiceAccount.getAccountCreators()
}