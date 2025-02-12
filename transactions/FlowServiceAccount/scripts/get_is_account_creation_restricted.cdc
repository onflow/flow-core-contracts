import "FlowServiceAccount"

access(all) fun main(): Bool {
    return FlowServiceAccount.isAccountCreationRestricted()
}