import FlowFees from 0xFLOWFEES

pub fun main(): {String: UFix64} {
    return { 
        "inclusionFactor": FlowFees.inclusionFactor,
        "computationFactor": FlowFees.computationFactor
    }
}