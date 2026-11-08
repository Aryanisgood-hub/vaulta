// Run with:  cd rules_tests && npm install && npx firebase emulators:exec --only firestore "npm test"
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { serverTimestamp, doc, setDoc, getDoc, updateDoc, deleteDoc, Timestamp, Bytes } = require('firebase/firestore');

let env;
const A = 'clubA', B = 'clubB';
const verified = (uid) =>
  env.authenticatedContext(uid, { email: `${uid}@x.com`, email_verified: true }).firestore();
const unverified = (uid) =>
  env.authenticatedContext(uid, { email: `${uid}@x.com`, email_verified: false }).firestore();

const clubDoc = () => ({
  name: 'Club A', email: 'clubA@x.com', totalBudget: 0,
  categories: ['Food'], members: [], createdAt: serverTimestamp(),
});
const bill = (over = {}) => ({
  eventId: 'e1', eventName: 'Hack', amount: 10000, reason: 'Pizza', paidTo: 'Shop',
  category: 'Food', date: Timestamp.now(), doneBy: 'Asha', status: 'active',
  createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...over,
});
const seeded = (over = {}) => ({ ...bill(over), createdAt: Timestamp.now(), updatedAt: Timestamp.now() });

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'vaulta-test',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
                 host: '127.0.0.1', port: 8080 },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `clubs/${A}`), { name: 'Club A', email: 'clubA@x.com', totalBudget: 500000,
      categories: [], members: [], createdAt: Timestamp.now() });
    await setDoc(doc(db, `clubs/${A}/bills/b1`), seeded());
    await setDoc(doc(db, `clubs/${A}/bills/voided`), seeded({ status: 'void' }));
    await setDoc(doc(db, `clubs/${A}/events/e1`), { name: 'Hack', date: Timestamp.now(), createdAt: Timestamp.now(),
      reimbursementAvailable: true, reimbursementAmount: 500000 });
  });
});

test('1. anonymous users cannot read anything', async () => {
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `clubs/${A}`)));
});
test('2. unverified email cannot read own club', async () => {
  await assertFails(getDoc(doc(unverified(A), `clubs/${A}`)));
});
test('3. a club can read its own data', async () => {
  await assertSucceeds(getDoc(doc(verified(A), `clubs/${A}/bills/b1`)));
});
test('4. a club cannot read another club', async () => {
  await assertFails(getDoc(doc(verified(B), `clubs/${A}/bills/b1`)));
});
test('5. a club cannot write into another club', async () => {
  await assertFails(setDoc(doc(verified(B), `clubs/${A}/bills/x`), bill()));
});
test('6. a club can register itself with zero budget', async () => {
  await assertSucceeds(setDoc(doc(verified(B), `clubs/${B}`), { ...clubDoc(), email: 'clubB@x.com' }));
});
test('7. a club cannot register itself with a starting budget', async () => {
  await assertFails(setDoc(doc(verified(B), `clubs/${B}`), { ...clubDoc(), email: 'clubB@x.com', totalBudget: 999 }));
});
test('8. valid bill can be created', async () => {
  await assertSucceeds(setDoc(doc(verified(A), `clubs/${A}/bills/new`), bill()));
});
test('9. fake timestamps are rejected', async () => {
  await assertFails(setDoc(doc(verified(A), `clubs/${A}/bills/new`),
    bill({ createdAt: Timestamp.fromDate(new Date('2020-01-01')) })));
});
test('10. float / zero / negative amounts are rejected', async () => {
  for (const amount of [10.5, 0, -5]) {
    await assertFails(setDoc(doc(verified(A), `clubs/${A}/bills/bad`), bill({ amount })));
  }
});
test('11. bills cannot be created as already voided', async () => {
  await assertFails(setDoc(doc(verified(A), `clubs/${A}/bills/bad`), bill({ status: 'void' })));
});
test('12. active bill can be edited', async () => {
  await assertSucceeds(updateDoc(doc(verified(A), `clubs/${A}/bills/b1`),
    { amount: 20000, updatedAt: serverTimestamp() }));
});
test('13. active bill can be voided', async () => {
  await assertSucceeds(updateDoc(doc(verified(A), `clubs/${A}/bills/b1`),
    { status: 'void', voidReason: 'duplicate', voidedAt: serverTimestamp(), updatedAt: serverTimestamp() }));
});
test('14. voided bills are frozen', async () => {
  await assertFails(updateDoc(doc(verified(A), `clubs/${A}/bills/voided`),
    { amount: 1, updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(verified(A), `clubs/${A}/bills/voided`),
    { status: 'active', updatedAt: serverTimestamp() }));
});
test('15. bills can never be deleted', async () => {
  await assertFails(deleteDoc(doc(verified(A), `clubs/${A}/bills/b1`)));
});
test('16. history is append-only', async () => {
  const ref = doc(verified(A), `clubs/${A}/bills/b1/history/h1`);
  await assertSucceeds(setDoc(ref, { action: 'edit', by: 'Asha', summary: 's', at: serverTimestamp() }));
  await assertFails(updateDoc(ref, { by: 'Someone else' }));
  await assertFails(deleteDoc(ref));
});
test('18. budget log is append-only', async () => {
  const ref = doc(verified(A), `clubs/${A}/budgetLog/l1`);
  await assertSucceeds(setDoc(ref, { oldBudget: 0, newBudget: 500000, by: 'Asha', reason: 'init', at: serverTimestamp() }));
  await assertFails(deleteDoc(ref));
});
test('19. income can only be voided, not edited or deleted', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `clubs/${A}/income/i1`),
      { amount: 5000, source: 'Sponsor', type: 'Sponsorship', doneBy: 'Asha', status: 'active',
        date: Timestamp.now(), createdAt: Timestamp.now() });
  });
  const ref = doc(verified(A), `clubs/${A}/income/i1`);
  await assertFails(updateDoc(ref, { amount: 9999999 }));
  await assertFails(deleteDoc(ref));
  await assertSucceeds(updateDoc(ref, { status: 'void', voidReason: 'wrong', voidedAt: serverTimestamp() }));
});
test('20. the club document can never be deleted', async () => {
  await assertFails(deleteDoc(doc(verified(A), `clubs/${A}`)));
});

const receipt = (size = 1000, over = {}) => ({
  data: Bytes.fromUint8Array(new Uint8Array(size)), contentType: 'image/jpeg',
  name: 'r.jpg', size, createdAt: serverTimestamp(), ...over,
});
test('21. a club can store and read its own receipt', async () => {
  const ref = doc(verified(A), `clubs/${A}/receipts/r1`);
  await assertSucceeds(setDoc(ref, receipt()));
  await assertSucceeds(getDoc(ref));
});
test('22. oversized receipts and wrong file types are rejected', async () => {
  await assertFails(setDoc(doc(verified(A), `clubs/${A}/receipts/big`), receipt(716801)));
  await assertFails(setDoc(doc(verified(A), `clubs/${A}/receipts/exe`), receipt(1000, { contentType: 'application/x-msdownload' })));
});
test('23. receipts are immutable and private', async () => {
  const ref = doc(verified(A), `clubs/${A}/receipts/r2`);
  await assertSucceeds(setDoc(ref, receipt()));
  await assertFails(updateDoc(ref, { name: 'changed.jpg' }));
  await assertFails(deleteDoc(ref));
  await assertFails(getDoc(doc(verified(B), `clubs/${A}/receipts/r2`)));
  await assertFails(setDoc(doc(verified(B), `clubs/${A}/receipts/r3`), receipt()));
});

const event = (over = {}) => ({
  name: 'Fest', date: Timestamp.now(), createdAt: serverTimestamp(),
  reimbursementAvailable: true, reimbursementAmount: 250000, ...over,
});
test('24. an event can be created with a reimbursement amount', async () => {
  await assertSucceeds(setDoc(doc(verified(A), `clubs/${A}/events/new`), event()));
  await assertSucceeds(setDoc(doc(verified(A), `clubs/${A}/events/none`),
    event({ reimbursementAvailable: false, reimbursementAmount: 0 })));
});
test('25. bad reimbursement values on events are rejected', async () => {
  const ref = doc(verified(A), `clubs/${A}/events/bad`);
  await assertFails(setDoc(ref, event({ reimbursementAmount: -5 })));
  await assertFails(setDoc(ref, event({ reimbursementAmount: 10.5 })));
  await assertFails(setDoc(ref, event({ reimbursementAvailable: false, reimbursementAmount: 100 })));
  await assertFails(setDoc(ref, { name: 'Fest', date: Timestamp.now(), createdAt: serverTimestamp() }));
});
test('26. an event reimbursement amount can be changed, but events cannot be deleted', async () => {
  const ref = doc(verified(A), `clubs/${A}/events/e1`);
  await assertSucceeds(updateDoc(ref, { reimbursementAmount: 700000 }));
  await assertFails(deleteDoc(ref));
});
const entry = (over = {}) => ({
  eventId: 'e1', eventName: 'Hack', amount: 100000, date: Timestamp.now(), note: '',
  doneBy: 'Asha', status: 'active', createdAt: serverTimestamp(), ...over,
});
test('27. reimbursement money received can be recorded for a real event', async () => {
  await assertSucceeds(setDoc(doc(verified(A), `clubs/${A}/reimbursements/r1`), entry()));
});
test('28. received entries must have a valid amount and an existing event', async () => {
  const ref = doc(verified(A), `clubs/${A}/reimbursements/bad`);
  await assertFails(setDoc(ref, entry({ eventId: 'ghost' })));
  await assertFails(setDoc(ref, entry({ amount: 0 })));
  await assertFails(setDoc(ref, entry({ amount: 12.5 })));
  await assertFails(setDoc(ref, entry({ createdAt: Timestamp.fromDate(new Date('2020-01-01')) })));
});
test('29. received entries can only be voided, never edited or deleted', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `clubs/${A}/reimbursements/r2`), { ...entry(), createdAt: Timestamp.now() });
  });
  const ref = doc(verified(A), `clubs/${A}/reimbursements/r2`);
  await assertFails(updateDoc(ref, { amount: 999999 }));
  await assertFails(deleteDoc(ref));
  await assertSucceeds(updateDoc(ref, { status: 'void', voidReason: 'wrong', voidedAt: serverTimestamp() }));
});
test('30. other clubs cannot see or add reimbursement entries', async () => {
  await assertFails(setDoc(doc(verified(B), `clubs/${A}/reimbursements/x`), entry()));
  await assertFails(getDoc(doc(verified(B), `clubs/${A}/reimbursements/r1`)));
});

test('31. an event can be renamed and re-dated', async () => {
  await assertSucceeds(updateDoc(doc(verified(A), `clubs/${A}/events/e1`),
    { name: 'Hackathon 2026', description: 'Main hall', date: Timestamp.now(),
      reimbursementAvailable: true, reimbursementAmount: 500000 }));
});
test('32. an event cannot be renamed to an empty name', async () => {
  await assertFails(updateDoc(doc(verified(A), `clubs/${A}/events/e1`), { name: '' }));
});
