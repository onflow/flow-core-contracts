import FlowDKG from 0xDKGADDRESS

pub struct Thresholds {
    pub let native: UInt64
    pub let safe: UInt64
    pub let safePercentage: UFix64

    init() {
        self.native = FlowDKG.getNativeSuccessThreshold()
        self.safe = FlowDKG.getSafeSuccessThreshold()
        self.safePercentage = FlowDKG.getSafeThresholdPercentage() ?? 0.0
    }
}

pub fun main(): Thresholds {
    return Thresholds()
}