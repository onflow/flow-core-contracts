import "FlowTransactionScheduler"

access(all) fun main(): {FlowTransactionScheduler.SchedulerConfig} {
    let config = FlowTransactionScheduler.getConfig()
    return config
}
