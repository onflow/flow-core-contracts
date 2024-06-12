
/// Saves an amount to storage that represent the amount
/// of bonus tokens that have yet to be burned
/// This amount is subtracted from the total supply of FLOW
/// whenever a new total rewards amount is calculated every epoch
/// because they are not meant to be a part of the total supply
/// 
/// Eventually, all bonus tokens will be burned and the amount will be zero

transaction(bonusTokenAmount: UFix64) {
    prepare(signer: auth(Storage) &Account) {
        signer.storage.load<UFix64>(from: /storage/FlowBonusTokenAmount)
        signer.storage.save(bonusTokenAmount, to: /storage/FlowBonusTokenAmount)
    }
}