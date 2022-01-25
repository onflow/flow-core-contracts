// Retrieves all current vouchers and returns the count.

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

pub fun main(): Int {
    let vouchers = FlowContractAudits.getAllVouchers()
    return vouchers.length
}