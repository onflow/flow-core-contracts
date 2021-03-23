import FlowEpoch from 0xEPOCHADDRESS

pub fun main(epochCounter: UInt64): FlowEpoch.EpochMetadata {
    return FlowEpoch.getEpochMetadata(epochCounter)!
}