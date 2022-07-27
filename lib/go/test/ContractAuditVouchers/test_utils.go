package main

import (
	"fmt"
	"testing"

	"github.com/bjartek/overflow"
	"github.com/onflow/cadence"
)

const (
	TestContractCode     = "contract CodyCode {}"
	TestContractCodeSHA3 = "cd1057bd9f593dab406b0a09ffcc7f7468d3ef85021884c4b07430933d94fec0"

	TransactionBasePath = "../../../../transactions/contractAudits/"
	ScriptBasePath      = "../../../../transactions/contractAudits/scripts/"

	AuditorInitTx                 = "auditor/init"
	AuditorNewAuditTx             = "auditor/new_audit"
	AuditorNewAuditHashedTx       = "auditor/new_audit_hashed"
	AuditorDeleteAuditTx          = "auditor/remove_audit"
	AdminAuthorizeAuditorTx       = "admin/authorize_auditor"
	AdminCleanupExpiredVouchersTx = "admin/cleanup_expired"
	DeveloperDeployContractTx     = "fvm/deploy_contract"

	GetVouchersScript = "get_vouchers"

	AuditorAccount    = "auditor"
	DeveloperAccount  = "developer"
	DeveloperAccount2 = "developer2"
	DeveloperAccount3 = "developer3"

	AuditorCreatedEventName = "A.f8d6e0586b0a20c7.FlowContractAudits.AuditorCreated"
	VoucherCreatedEventName = "A.f8d6e0586b0a20c7.FlowContractAudits.VoucherCreated"
	VoucherUsedEventName    = "A.f8d6e0586b0a20c7.FlowContractAudits.VoucherUsed"
	VoucherRemovedEventName = "A.f8d6e0586b0a20c7.FlowContractAudits.VoucherRemoved"

	ErrorNoVoucher = "invalid voucher"
)

// authorizeAuditor initializes the auditor account and deposits the needed capability by admin.
func authorizeAuditor(g *overflow.OverflowState, t *testing.T) {
	// auditor init proxy
	g.TransactionFromFile(AuditorInitTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAs(AuditorAccount).
		Test(t).
		AssertSuccess()

	// admin authorizes auditor
	g.TransactionFromFile(AdminAuthorizeAuditorTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Args(g.Arguments().Account(AuditorAccount)).
		Test(t).
		AssertSuccess().
		AssertEmitEventName(AuditorCreatedEventName)
}

// deployAndFail deploys the test contract to the provided account and assert failure.
func deployAndFail(g *overflow.OverflowState, t *testing.T, account string) {
	g.TransactionFromFile(DeveloperDeployContractTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Args(g.Arguments().
			Account(account).
			String(TestContractCode)).
		Test(t).
		AssertFailure(ErrorNoVoucher)
}

// auditContract creates new audit voucher.
// If `anyAccount` is false, the voucher will be created for DeveloperAccount.
// If `expiryOffset` is <= 0, expiryOffset? will be nil.
func auditContract(g *overflow.OverflowState, t *testing.T, anyAccount bool, recurrent bool, expiryOffset int, expiryBlockHeight int, hashed bool) {

	var argBuilder *overflow.OverflowArgumentsBuilder
	var address string
	if anyAccount {
		argBuilder = g.Arguments().Argument(cadence.NewOptional(nil))
	} else {
		address = "0x" + g.Account(DeveloperAccount).Address().String()
		acc := g.Account(DeveloperAccount)
		argBuilder = g.Arguments().Argument(cadence.NewOptional(cadence.NewAddress(acc.Address())))
	}

	var builder overflow.OverflowInteractionBuilder
	if hashed {
		builder = g.TransactionFromFile(AuditorNewAuditHashedTx).
			TransactionPath(TransactionBasePath)
		argBuilder = argBuilder.String(TestContractCodeSHA3)
	} else {
		builder = g.TransactionFromFile(AuditorNewAuditTx).
			TransactionPath(TransactionBasePath)
		argBuilder = argBuilder.String(TestContractCode)
	}

	argBuilder = argBuilder.
		Boolean(recurrent)

	if expiryOffset > 0 {
		argBuilder = argBuilder.Argument(cadence.NewOptional(cadence.NewUInt64(uint64(expiryOffset))))

		result := builder.SignProposeAndPayAs(AuditorAccount).
			Args(argBuilder).
			Test(t).
			AssertSuccess()

		if address == "" {
			// result.AssertEmitEvent(overflow.NewTestEvent(VoucherCreatedEventName, map[string]interface{}{
			// 	"codeHash":          TestContractCodeSHA3,
			// 	"expiryBlockHeight": expiryBlockHeight,
			// 	"recurrent":         recurrent,
			// }))
		} else {
			result.AssertEmitEvent(overflow.NewTestEvent(VoucherCreatedEventName, map[string]interface{}{
				"address":           address,
				"codeHash":          TestContractCodeSHA3,
				"expiryBlockHeight": expiryBlockHeight,
				"recurrent":         recurrent,
			}))
		}
	} else {
		argBuilder = argBuilder.Argument(cadence.NewOptional(nil))

		result := builder.SignProposeAndPayAs(AuditorAccount).
			Args(argBuilder).
			Test(t).
			AssertSuccess()

		if address == "" {
			result.AssertEmitEvent(overflow.NewTestEvent(VoucherCreatedEventName, map[string]interface{}{
				"codeHash":  TestContractCodeSHA3,
				"recurrent": recurrent,
			}))
		} else {
			result.AssertEmitEvent(overflow.NewTestEvent(VoucherCreatedEventName, map[string]interface{}{
				"address":   address,
				"codeHash":  TestContractCodeSHA3,
				"recurrent": recurrent,
			}))
		}
	}
}

// deploys the test contract to the provided account.
// The initial voucher creation arguments are passed to check against the resulting events.
func deploy(g *overflow.OverflowState, t *testing.T, account string, recurrent bool, expiryBlockHeight int, anyAccountVoucher bool) {
	key := fmt.Sprintf("0x%s-%s", g.Account(account).Address().String(), TestContractCodeSHA3)
	if anyAccountVoucher {
		key = fmt.Sprintf("any-%s", TestContractCodeSHA3)
	}

	result := g.TransactionFromFile(DeveloperDeployContractTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Args(g.Arguments().
			Account(account).
			String(TestContractCode)).
		Test(t).
		AssertSuccess()

	if expiryBlockHeight > 0 {
		// result.AssertEmitEvent(overflow.NewTestEvent(VoucherUsedEventName, map[string]interface{}{
		// 	"address":           "0x" + g.Account(account).Address().String(),
		// 	"key":               key,
		// 	"expiryBlockHeight": expiryBlockHeight,
		// 	"recurrent":         recurrent,
		// }))
	} else {
		result.AssertEmitEvent(overflow.NewTestEvent(VoucherUsedEventName, map[string]interface{}{
			"address":   "0x" + g.Account(account).Address().String(),
			"key":       key,
			"recurrent": recurrent,
		}))
	}

	if !recurrent {
		if expiryBlockHeight > 0 {
			// result.AssertEmitEvent(overflow.NewTestEvent(VoucherRemovedEventName, map[string]interface{}{
			// 	"key":               key,
			// 	"expiryBlockHeight": expiryBlockHeight,
			// 	"recurrent":         recurrent,
			// }))
		} else {
			result.AssertEmitEvent(overflow.NewTestEvent(VoucherRemovedEventName, map[string]interface{}{
				"key":       key,
				"recurrent": recurrent,
			}))
		}
	}
}

// getVouchersCount returns the count of current vouchers.
func getVouchersCount(g *overflow.OverflowState, t *testing.T) int {
	countVouchers, err := g.ScriptFromFile(GetVouchersScript).ScriptPath(ScriptBasePath).RunReturns()
	if err != nil {
		fmt.Println(err)
		t.Fail()
	}
	c := countVouchers.(cadence.Int)
	return c.Int()
}
