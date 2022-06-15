import FlowServiceAccount from 0xFLOWSERVICEADDRESS

pub fun main(): UInt64 {
    return FlowServiceAccount.getExecutionMemoryLimit()
}