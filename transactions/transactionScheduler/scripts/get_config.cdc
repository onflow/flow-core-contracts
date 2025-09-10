import "FlowTransactionScheduler"

access(all) fun main(): {FlowTransactionScheduler.SchedulerConfig} {
    return FlowTransactionScheduler.getSchedulerConfigurationDetails()
}
