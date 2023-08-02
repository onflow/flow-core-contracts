import FlowDKG from 0xDKGADDRESS

access(all) struct Thresholds {
    access(all) let native: UInt64
    access(all) let safe: UInt64
    access(all) let safePercentage: UFix64

    init() {
        self.native = FlowDKG.getNativeSuccessThreshold()
        self.safe = FlowDKG.getSafeSuccessThreshold()
        self.safePercentage = FlowDKG.getSafeThresholdPercentage() ?? 0.0
    }
}

access(all) fun main(): Thresholds {
    return Thresholds()
}