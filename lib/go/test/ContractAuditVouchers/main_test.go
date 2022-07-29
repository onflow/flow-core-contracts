package main

import (
	"fmt"
	"testing"

	"github.com/bjartek/overflow"
	"github.com/onflow/cadence"
)

func TestDeployContract(t *testing.T) {

	g, _ := overflow.OverflowTesting()

	// no voucher on start
	deployAndFail(g, t, DeveloperAccount)

	// init auditor
	authorizeAuditor(g, t)

	// auditor creates new voucher for developer account
	auditContract(g, t, false, false, 0, 0, false)

	// developer cannot deploy to another account
	deployAndFail(g, t, DeveloperAccount2)
	deployAndFail(g, t, DeveloperAccount3)

	// developer can deploy audited contract
	deploy(g, t, DeveloperAccount, false, 0, false)

	// developer cannot deploy audited contract twice
	deployAndFail(g, t, DeveloperAccount)
}

func TestDeployRecurrentContract(t *testing.T) {
	g := overflow.NewTestingEmulator().Start()

	// init auditor
	authorizeAuditor(g, t)

	// auditor adds recurrent voucher for any account
	auditContract(g, t, true, true, 0, 0, false)

	// developer can deploy audited contract
	deploy(g, t, DeveloperAccount, true, 0, true)

	// developer can deploy audited contract again
	deploy(g, t, DeveloperAccount2, true, 0, true)
	deploy(g, t, DeveloperAccount3, true, 0, true)

	// auditor updates voucher to non-recurrent for any account
	g.TransactionFromFile(AuditorNewAuditTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAs(AuditorAccount).
		Args(g.Arguments().
			Argument(cadence.NewOptional(nil)).
			String(TestContractCode).
			Boolean(false).
			Argument(cadence.NewOptional(cadence.NewUInt64(1)))).
		Test(t).
		AssertSuccess().
		// AssertEmitEvent(overflow.NewTestEvent(VoucherCreatedEventName, map[string]interface{}{
		// 	"codeHash":          TestContractCodeSHA3,
		// 	"expiryBlockHeight": 12,
		// 	"recurrent":         false,
		// })).
		AssertEmitEvent(overflow.NewTestEvent(VoucherRemovedEventName, map[string]interface{}{
			"key":       fmt.Sprintf("any-%s", TestContractCodeSHA3),
			"recurrent": true,
		}))

	// developer deploys and uses voucher
	deploy(g, t, DeveloperAccount, false, 12, true)

	// developer cannot deploy any more
	deployAndFail(g, t, DeveloperAccount)
}

func TestDeleteVoucher(t *testing.T) {
	g := overflow.NewTestingEmulator().Start()

	// init auditor
	authorizeAuditor(g, t)

	// auditor adds recurrent voucher
	auditContract(g, t, false, true, 0, 0, false)

	// developer can deploy audited contract
	deploy(g, t, DeveloperAccount, true, 0, false)

	// delete voucher
	g.TransactionFromFile(AuditorDeleteAuditTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAs(AuditorAccount).
		Args(g.Arguments().
			String(fmt.Sprintf("0x%s-%s", g.Account(DeveloperAccount).Address().String(), TestContractCodeSHA3))).
		Test(t).
		AssertSuccess().
		AssertEmitEvent(overflow.NewTestEvent(VoucherRemovedEventName, map[string]interface{}{
			"key":       "0x" + g.Account(DeveloperAccount).Address().String() + "-" + TestContractCodeSHA3,
			"recurrent": true,
		}))

	// developer cannot deploy any more
	deployAndFail(g, t, DeveloperAccount)
}

func TestExpiredVouchers(t *testing.T) {
	g := overflow.NewTestingEmulator().Start()

	// init auditor
	authorizeAuditor(g, t)

	// auditor adds recurrent voucher for any account
	auditContract(g, t, true, true, 2, 9, false)

	// developer can deploy audited contract for 2 blocks
	deploy(g, t, DeveloperAccount, true, 9, true)
	deploy(g, t, DeveloperAccount2, true, 9, true)

	// voucher expired
	deployAndFail(g, t, DeveloperAccount3)
}

func TestCleanupExpired(t *testing.T) {
	g := overflow.NewTestingEmulator().Start()

	// init auditor
	authorizeAuditor(g, t)

	// auditor adds recurrent voucher for any account
	auditContract(g, t, true, true, 1, 8, false)

	// check count
	if getVouchersCount(g, t) != 1 {
		t.Fail()
	}

	// cleanup
	g.TransactionFromFile(AdminCleanupExpiredVouchersTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Test(t).
		AssertSuccess()

	// check count, block offset still valid
	if getVouchersCount(g, t) != 1 {
		t.Fail()
	}

	// cleanup
	g.TransactionFromFile(AdminCleanupExpiredVouchersTx).
		TransactionPath(TransactionBasePath).
		SignProposeAndPayAsService().
		Test(t).
		AssertSuccess()

	// verify cleanup
	if getVouchersCount(g, t) != 0 {
		t.Fail()
	}
}

func TestHashedDeployContract(t *testing.T) {

	g := overflow.NewTestingEmulator().Start()

	// no voucher on start
	deployAndFail(g, t, DeveloperAccount)

	// init auditor
	authorizeAuditor(g, t)

	// auditor creates new voucher for developer account
	auditContract(g, t, false, false, 0, 0, true)

	// developer cannot deploy to another account
	deployAndFail(g, t, DeveloperAccount2)
	deployAndFail(g, t, DeveloperAccount3)

	// developer can deploy audited contract
	deploy(g, t, DeveloperAccount, false, 0, false)

	// developer cannot deploy audited contract twice
	deployAndFail(g, t, DeveloperAccount)
}
