package main

import (
	"fmt"
	"testing"

	. "github.com/bjartek/overflow"
	"github.com/onflow/cadence"
)

var testingOptions = []OverflowOption{
	WithoutTransactionFees(),
	WithNetwork("testing"),
	WithFlowForNewUsers(0.0),
	WithBasePath(BasePath),
	WithTransactionFolderName(TransactionFolderName),
	WithScriptFolderName(ScriptFolderName),
}

func TestDeployContract(t *testing.T) {

	g := Overflow(testingOptions...)

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

	g := Overflow(testingOptions...)

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
	g.Tx(AuditorNewAuditTx,
		WithSigner(AuditorAccount),
		WithArg("address", cadence.NewOptional(nil)),
		WithArg("code", TestContractCode),
		WithArg("recurrent", false),
		WithArg("expiryOffset", 1),
	).AssertSuccess(t).
		AssertEvent(t, VoucherCreatedEventName, map[string]interface{}{
			"recurrent":         false,
			"expiryBlockHeight": 12,
			"codeHash":          TestContractCodeSHA3,
		}).
		AssertEvent(t, VoucherRemovedEventName, map[string]interface{}{
			"key":       fmt.Sprintf("any-%s", TestContractCodeSHA3),
			"recurrent": true,
		})

	// developer deploys and uses voucher
	deploy(g, t, DeveloperAccount, false, 12, true)

	// developer cannot deploy any more
	deployAndFail(g, t, DeveloperAccount)
}

func TestDeleteVoucher(t *testing.T) {

	g := Overflow(testingOptions...)

	// init auditor
	authorizeAuditor(g, t)

	// auditor adds recurrent voucher
	auditContract(g, t, false, true, 0, 0, false)

	// developer can deploy audited contract
	deploy(g, t, DeveloperAccount, true, 0, false)

	// delete voucher
	g.Tx(AuditorDeleteAuditTx,
		WithSigner(AuditorAccount),
		WithArg("key", fmt.Sprintf("%s-%s", g.Address(DeveloperAccount), TestContractCodeSHA3)),
	).AssertSuccess(t).
		AssertEvent(t, VoucherRemovedEventName, map[string]interface{}{
			"key":       g.Address(DeveloperAccount) + "-" + TestContractCodeSHA3,
			"recurrent": true,
		})

	// developer cannot deploy any more
	deployAndFail(g, t, DeveloperAccount)
}

func TestExpiredVouchers(t *testing.T) {

	g := Overflow(testingOptions...)
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
	g := Overflow(testingOptions...)

	// init auditor
	authorizeAuditor(g, t)

	// auditor adds recurrent voucher for any account
	auditContract(g, t, true, true, 1, 8, false)

	// check count
	if getVouchersCount(g, t) != 1 {
		t.Fail()
	}

	// cleanup
	g.Tx(AdminCleanupExpiredVouchersTx, WithSignerServiceAccount()).AssertSuccess(t)

	// check count, block offset still valid
	if getVouchersCount(g, t) != 1 {
		t.Fail()
	}

	// cleanup
	g.Tx(AdminCleanupExpiredVouchersTx, WithSignerServiceAccount()).AssertSuccess(t)

	// verify cleanup
	if getVouchersCount(g, t) != 0 {
		t.Fail()
	}
}

func TestHashedDeployContract(t *testing.T) {

	g := Overflow(testingOptions...)

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
