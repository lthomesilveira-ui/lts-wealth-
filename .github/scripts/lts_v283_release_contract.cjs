// V283 label-presentation release contract, derived from the reviewed V282 contract.
// Baseline and candidate hashes are pinned from the public labels-v282 allowlist.
// Run from the repository root; this gate is read-only and performs no network I/O.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');

const BASE_RELEASE = 'v282';
const RELEASE = 'v283';
const BASE_COMMIT = 'd1e972d69390112714a0d676bfd966f8477f14b0';
const BASE_FILES = {
  "app.html": "6ddbfe7f19b7a17c911186c0e7f9fd96a41dbe270238fe1e7a42e4ab5b26c3e1",
  "index.html": "0ccf1a5b03bd550a470fa3443fe6227e3ae74d8a8f10268f2f59a349d4781ed6",
  "lts-dashboard-executive-v1.js": "527f93e991abf083d109a495603d664db7a3b1b48aea7f6b9713f84f12615121",
  "lts-dashboard-read-model.js": "ec2b3615c65fe194b6a6f5589190184c58c4da5aa5c0da044848d3807640d420",
  "lts-executive-visual-system-v2.css": "08fd5215bb212720ee98ad72b6122ab9c4ac8f8d7ffbff24ef2ab792dd6ce77d",
  "lts-executive-visual-system-v2.js": "360d117686c42f508b423cd3d34b0c6ae746aa4027229f9c032463a438f4c70f",
  "lts-expense-read-model.js": "76a3d91df2af59256b23c9969e719963a17cd98a51df361742491b074cd60fba",
  "lts-expense-screen-alignment.js": "1a26f9aee82b59a4e34a5d84201aada1553a54d8053d3551e681ba5ac263b6c5",
  "lts-history-coverage-policy.js": "583c3a2566fc5b93cc012ed99ce95a2ff88890cb83ce6073082b8ce527b68106",
  "lts-v166-feedback-closure.css": "0ebb44bd44467ce474eab4661c672e95775ab490b818ab1d02f4f941fe2a5bfb",
  "lts-v166-feedback-closure.js": "432f953d2846f296ee969e15f388619aca9e96af456b6a70f55880f44dd0a2fa",
  "lts-v168-feedback-package.css": "397f04c02ee96b1d7acae82bf0ca41239aca643c10c23a27dccbca05772ce6bc",
  "lts-v169-v168-feedback-closure.css": "67e588a9bcd569168a5ba753f2ad8f614668cef2b09f3a308b8998ee656512da",
  "lts-v169-v168-feedback-closure.js": "c41f1361fe5a6cb26ad9d640ed782d626bae162c1f1f6fb487f3db67ea6e2c93",
  "lts-v170-v169-review.css": "e9e1de863f4a0887336cad7142489505d51efe98cd3835573be6c08e8935724d",
  "lts-v170-v169-review.js": "af4f9cf137b1f0a0d8e8636c35371c8a136313adc39b9e9141a2d3cf3b2f8455",
  "lts-v171-v170-review.css": "fefe14999ceb7da28acbd84189cb2f27b4066ed75293bba26f41ee144de02b97",
  "lts-v171-v170-review.js": "7b712917c48d1b1d39dd6a27bd8a5a2409aa72cec8af189859a2e9595ee01d37",
  "lts-v172-v171-review.css": "997cef48021737697be4649ee7d30739b664f1f012d6fafe14350b77218d0c91",
  "lts-v172-v171-review.js": "c91636929980bfea8d3456c76784b5d7f1aea344c6e7ab84f734edc1a6dfb5c2",
  "lts-v173-v172-feedback.css": "3e9f0535e1fe55514af262b505321464afb13bfe024b1a721e80f9182e6e107f",
  "lts-v174-v173-review.css": "f526f69dd2f87af20464931249e7cb46da2ddb6f7fb7d0c130a500dc150ae00c",
  "lts-v174-v173-review.js": "bc32f55be5fa2f46d7f6167412f7d8ed984e1454eae81712708e7d72ac8e508e",
  "lts-v175-expense-financial-audit.css": "d8681b85fe0a6d69cf98e0b6fecb1c063321c68fd65e15c1b96a887468fbf5e2",
  "lts-v176-flow-expense-audit.css": "b3f571a42a6b2398c760ef5dfe9ec5ebc3117932c33df3e0a3c532809a04a328",
  "lts-v176-flow-expense-audit.js": "4afce88a62fc5d14e10697aa3c996211e47d154fa28f0e36773087ee323baed6",
  "lts-v178-integrated-review.css": "0d8dd9eb33522b0fe4b8961646d6882d122e2310ff1cb7f8891ebb0fd52be809",
  "lts-v178-review-actions.js": "372651fa4d1913856c35bc646dd46d3751ad17ba7793eec2ae62f6b44e6af58e",
  "lts-v179-cash-recovery.js": "8294c4cd80932efaff06b47f73851aa5479d2e61ab3dbed81ed55ee70c175f5a",
  "lts-v180-documentary-refresh.js": "4bc410b4bb81e518eea4d87f94aaac173e6f0d78d769e94dc229d454c05486d4",
  "lts-v181-regression-closure.css": "26b23698e1b8a07b05752e2dd96241a670fc8f52c4540a08a9b8bfe4bdc383f6",
  "lts-v181-regression-closure.js": "7d50f9ddce190a680e4d532057723a8cc8931e9630b1a66b8ed8b49ccca735fe",
  "lts-v183-award-provenance.js": "2dfc725f92c361001844be1d3b0fb43be84b94f446976e09ba4ad6f45e30e029",
  "lts-v183-card-payment-status.js": "c96317ad7fa07c2e4fae6651a6b4a7227ee42d3a13e8e3df35928058c9fd8d88",
  "lts-v183-card-period-candidate.js": "2dda4ebb991f3acffc9b59f2f0b5362a813bbaa78747105d16e36f85b80c125e",
  "lts-v183-core-loading-guard.js": "f3b4971b051eb00f9daa7a3f7ec5a9b47639810e0f7521df4e4c9b6ec4b29b4a",
  "lts-v183-exact-flow-navigation.js": "588183c8daf1e30bbb7a912cc63fccec978335cbdbc0df88f8580e83210a7861",
  "lts-v183-expense-history-candidate.js": "ff0b6997cf319cb3a7069292c847caf539155c8e279e865e2348d32742f30e32",
  "lts-v183-flow-period-state.js": "a58a5bc7d0332fb50f91312ccbeb2e6f04ff42c8011d1f2b481862b6b8a2d105",
  "lts-v183-historical-balance-guard.js": "3e219fa163879f63dccfcd0d6dccaba365100391c65ea979c77da293915c1d53",
  "lts-v183-income-review.js": "c64bce436e26a256f4d1f7a5aefad54e6f019c7ad6d32af595e8076ea2dde9e6",
  "lts-v183-personal-image-labels.js": "57b8c2166da10018e586c73fef87689e0985847dd121ae87c6263b847c6127fd",
  "lts-v183-retention-composition.js": "632220ebef861bb135d6899d4191f9edfa6ef34941ac5c63527b29c91d060250",
  "lts-v183-rsu-component-labels.js": "b08d2b43f3b585e2b3993b6a1249bc94e15ad6a35c2069fbc19ba4769de106c5",
  "lts-v183-search-completeness.js": "0de2f03f22e7fd4e1ad6d8d97211d127b1873741bd4d65df06a34418be5fdfc2",
  "lts-v183-v168-feedback-safe.js": "dc0db5e2083c0d2d1085013dffb06ab623d4875853bd43b658b2ac51aabba34e",
  "lts-v183-v173-feedback-safe.js": "dd75d9e5b5583c44e809586531f5fa07fa20ccb47942017a5d381359e0f2ca35",
  "lts-v183-v182-feedback-safe.js": "d23bda5f94d21913eec0b841fe97a3f7ab90e009bc0c557a87935bbd77666351",
  "lts-v183-wealth-debt-integrity.js": "c1746a09de461a277aed83adc110ca2b75dec70a6f8836be2f2e389e2a943343",
  "lts-v225-consolidated.css": "d56b997a7fc9b39ac902e6f94fd4cc51769e30f1f9ddd2be1d271d5472790bce",
  "lts-v225-open-finance.js": "9a21e6c8e8f2b49185e9881804561f347258cdbfccdd48315ed09a8dd766146c",
  "lts-v226-card-composition.css": "07d788c53457f428cda84736baf9e6b240d53e3cc3b0bb7a6a16866c6ac1a72a",
  "lts-v226-card-composition.js": "e76f4d63e81d435c16790fd0a9063bd895d96e042955f9bc3fe4ec5cc80bbf49",
  "lts-v227-layout.js": "f99596a68af577a1dc447287f2de6d1006f44bf2bd98a1ba4c35b0f08bab2c46",
  "lts-v227-read-transport.js": "9b8384ee0ba4e4925933f72ef58b954ec67723b646b9fa2ac4433311b4abd9d0",
  "lts-v228-bank-flow.js": "d89a791e19111908c06875a769d331cdbe512a44ef0425be636c8ba6b99f03bf",
  "lts-v235-history-inventory.js": "52824599b5a53e8cbd2f5c289754f45b95a9cd7a48bc75e4366bc71860c638b6",
  "lts-v257-ui-state.js": "434a82ffdc7d6d68f86042a8823c2f1b23ef8226229be2fee77ed6f32e9ead27",
  "lts-v268-read-tools.js": "82fbf7f9a8df80162819f23d592bd966ee774c6cc94387dbeeaf2bb9087038ed",
  "provenance.json": "4f74ca348a31c08f2842051b38301187a1f126e179c78531c8b84ce1ee3de0e1",
  "wip35-v162-flow-recovery.js": "9a519b23052c2f807aeb5a2f20582710bc0466d6f5931db4edd70606ea4a9350",
  "lts-v269-client-contract.js": "de06729ab1b2688ced97258a69ff29696da1a58a8c5e8df18b32c56585169f6e",
  "lts-v269-incomplete-view.js": "a55de0d39b7ae27662dfd7010d2281477fd8acd02b55af09f9176a7e19e6d8e1",
  "lts-category-display.js": "75c7a0a48811811f632d0e666ad6687c9e112cd86a76da7e95737c773534472c",
  "lts-flow-invoice-target.js": "5636ac48c21538e2e508ff35ca768e9f7e485b5882efe664143ffd5b213a2a2f",
  "lts-v275-overdue-visibility.js": "75d0701fc84a7de7aeca00df3d12efe5474266c015343054c6849dcb2f9bc99c",
  "manifest.json": "ddafc3e0d2bb2ae3167f3d96b7ec7ed20e7821a5951886c3ca19c49209da92ac"
};
const CANDIDATE_FILES = {
  "lts-category-display.js": "38b3e6c9755d8e59a4c1cf81082103505302727ada6a8d72377bdfdf691b56cd",
  "lts-v178-review-actions.js": "f3daa35f928dc021a28aad2360c7c49db3a576de46ee7192784a6dec3f3daafa",
  "lts-v179-cash-recovery.js": "28c14bfca31162b2346d725abac4a1719220e8c0a98c1a432cc3636af90afd41",
  "lts-v181-regression-closure.js": "8a7247e7d5b41d4fe511d27edb95037924b97d4b7368d7a67ff4c36e5e833023",
  "lts-v183-expense-history-candidate.js": "ebf1d9a46d46765be69df81e20638189221e5e2b41ad8374732b5b972f66ffaf",
  "lts-v183-v168-feedback-safe.js": "86c34f63b964447e87b5fb37dd5c75fb2beda66de69120c2f91193bda2ab58ba",
  "lts-v183-v173-feedback-safe.js": "87ca338c95f96f793055fbda04b51158ee0ab37d07e3f6e5343eb9ceaf7cdc55",
  "lts-v183-v182-feedback-safe.js": "6f4d10f8013d892fb083a3fc9f812e883fbf84dde82d84155fbe089b93b9278d"
};
const APP_SHA256 = 'becf7ac7dec1cb3df9edb331fa322af0779b7785b19cffb74c04d28b54a0f5bc';
const METADATA_FILES = ['app.html', 'provenance.json'];
const beforeDir = path.join('releases', BASE_RELEASE);
const afterDir = path.join('releases', RELEASE);
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = filename => fs.readFileSync(filename);
const sortedKeys = value => Object.keys(value).sort();

function regularFiles(directory) {
  const entries = fs.readdirSync(directory, { withFileTypes: true });
  for (const entry of entries) {
    assert(entry.isFile(), `${directory}/${entry.name}: only regular release files are permitted`);
  }
  return entries.map(entry => entry.name).sort();
}

function object(value, label) {
  assert(value && typeof value === 'object' && !Array.isArray(value), `${label} must be an object`);
}

assert.equal(Object.keys(BASE_FILES).length, 67, 'Pinned baseline must contain 67 files');
assert.equal(Object.keys(CANDIDATE_FILES).length, 8, 'Exactly eight reviewed JS assets are allowed');
assert.deepEqual(regularFiles(beforeDir), sortedKeys(BASE_FILES), 'V282 file inventory differs from the reviewed baseline');
assert.deepEqual(regularFiles(afterDir), sortedKeys(BASE_FILES), 'V283 must contain the same exact 67 filenames, including manifest.json');

// Pin every V282 byte, including its manifest, before trusting the inherited history.
for (const [name, expected] of Object.entries(BASE_FILES)) {
  assert.equal(sha256(read(path.join(beforeDir, name))), expected, `Reviewed V282 SHA256: ${name}`);
}
const before = JSON.parse(read(path.join(beforeDir, 'manifest.json')));
const after = JSON.parse(read(path.join(afterDir, 'manifest.json')));
object(before.files, 'V282 manifest.files');
object(before.protected, 'V282 manifest.protected');
object(after.files, 'V283 manifest.files');
object(after.protected, 'V283 manifest.protected');
assert.deepEqual(sortedKeys(after), sortedKeys(before), 'Manifest metadata fields must remain unchanged');
assert.equal(after.release, RELEASE, 'V283 manifest release');
assert.equal(after.version, RELEASE, 'V283 manifest version');
const expectedFiles = Object.fromEntries(Object.entries(BASE_FILES).filter(([name]) => name !== 'manifest.json'));
assert.deepEqual(before.files, expectedFiles, 'V282 manifest must match the pinned public baseline');
assert.equal(Object.keys(after.files).length, 66, 'V283 manifest.files must contain exactly 66 entries');
assert.deepEqual(sortedKeys(after.files), sortedKeys(expectedFiles), 'V283 manifest file inventory must be unchanged');

const changedFiles = [];
for (const [name, expected] of Object.entries(after.files)) {
  assert.match(expected, /^[a-f0-9]{64}$/, `${name}: invalid manifest SHA256`);
  const actual = sha256(read(path.join(afterDir, name)));
  assert.equal(actual, expected, `V283 manifest SHA256: ${name}`);
  if (actual !== BASE_FILES[name]) changedFiles.push(name);
  if (Object.hasOwn(CANDIDATE_FILES, name)) {
    assert.equal(actual, CANDIDATE_FILES[name], `Reviewed label-presentation SHA256: ${name}`);
    assert.notEqual(actual, BASE_FILES[name], `${name}: reviewed candidate must differ from V282`);
  } else if (!METADATA_FILES.includes(name)) {
    assert.equal(actual, BASE_FILES[name], `Out-of-scope change: ${name}`);
  }
}
assert.deepEqual(changedFiles.sort(), [...Object.keys(CANDIDATE_FILES), ...METADATA_FILES].sort(),
  'Only the exact eight JS assets, app.html and provenance.json may differ from V282');
assert.deepEqual(changedFiles.filter(name => name.endsWith('.js')).sort(), sortedKeys(CANDIDATE_FILES),
  'The JS diff must contain the exact eight reviewed assets');

// The app wrapper may change only the release badge/title and the iframe cache key.
const beforeApp = read(path.join(beforeDir, 'app.html')).toString('utf8');
assert(beforeApp.includes('V282'), 'Reviewed app must contain the V282 marker');
assert(beforeApp.includes('v282-canonical-ledger-20261016'), 'Reviewed app must contain the V282 cache key');
const expectedApp = beforeApp.replaceAll('V282', 'V283')
  .replaceAll('v282-canonical-ledger-20261016', 'v283-label-presentation-20261016');
const actualApp = read(path.join(afterDir, 'app.html'));
assert.equal(actualApp.toString('utf8'), expectedApp, 'app.html must contain only the reviewed release/cache substitutions');
assert.equal(sha256(actualApp), APP_SHA256, 'Exact V283 app.html SHA256');
assert(read(path.join(beforeDir, 'index.html')).equals(read(path.join(afterDir, 'index.html'))),
  'index.html must remain byte-for-byte intact');

const provenance = JSON.parse(read(path.join(afterDir, 'provenance.json')));
object(provenance, 'V283 provenance');
assert.equal(provenance.release, RELEASE, 'Provenance release');
assert.equal(provenance.base_release, BASE_RELEASE, 'Provenance base release');
assert.equal(provenance.base_commit, BASE_COMMIT, 'Provenance must identify the exact reviewed V282 commit');
assert.equal(provenance.financial_sources_unchanged, true, 'Financial sources must remain unchanged');
assert.equal(provenance.backend_changed, false, 'No backend changes are permitted');
assert(Array.isArray(provenance.scope) && provenance.scope.length > 0 &&
  provenance.scope.every(item => typeof item === 'string' && item.trim().length > 0),
  'Provenance must declare a nonempty textual scope');

// Preserve the complete inherited history and protect every V282 asset, manifest included.
const expectedProtected = { ...before.protected };
for (const [name, hash] of Object.entries(BASE_FILES)) {
  const filename = `releases/${BASE_RELEASE}/${name}`;
  assert(!Object.hasOwn(expectedProtected, filename) || expectedProtected[filename] === hash,
    `Existing protected V282 hash conflicts: ${name}`);
  expectedProtected[filename] = hash;
}
assert.equal(Object.keys(before.protected).length, 1669, 'Reviewed historical protection count');
assert.equal(Object.keys(expectedProtected).length, 1736, 'History must add all 67 V282 files');
assert.deepEqual(after.protected, expectedProtected, 'Protected history must be preserved exactly, with all V282 hashes added');
for (const [filename, expected] of Object.entries(expectedProtected)) {
  assert.equal(sha256(read(filename)), expected, `Protected historical SHA256: ${filename}`);
}

console.log(JSON.stringify({
  pass: true,
  release: RELEASE,
  base_release: BASE_RELEASE,
  base_commit: BASE_COMMIT,
  total_files: 67,
  manifest_files: 66,
  reviewed_js_assets: 8,
  changed_files: changedFiles,
  index_unchanged: true,
  protected_files: Object.keys(expectedProtected).length
}, null, 2));
