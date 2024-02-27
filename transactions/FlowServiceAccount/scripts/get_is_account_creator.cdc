import FlowServiceAccount from "FlowServiceAccount"

access(all) fun main(address: Address): Bool {
    return FlowServiceAccount.isAccountCreator(address)
}