import FlowFreeze from 0xFREEZEADDRESS

pub fun main(address: Address): Bool {

    let freezeList = FlowFreeze.getFreezeList()

    return freezeList[address] != nil
}