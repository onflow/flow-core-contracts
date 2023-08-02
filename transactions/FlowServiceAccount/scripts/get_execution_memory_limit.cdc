import FlowServiceAccount from 0xFLOWSERVICEADDRESS

access(all) fun main(): UInt64 {
    return FlowServiceAccount.getExecutionMemoryLimit()
}