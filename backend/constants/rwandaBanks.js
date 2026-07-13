// Commercial banks licensed by the National Bank of Rwanda (BNR), with their
// head-office SWIFT/BIC codes. Mirrors lib/core/constants/rwanda_banks.dart —
// keep both lists in sync.
const RWANDA_BANKS = [
  { name: 'AB Bank Rwanda Plc', code: 'ABBRRWRW' },
  { name: 'Access Bank (Rwanda) Plc', code: 'BKORRWRW' },
  { name: 'Bank of Africa Rwanda Ltd', code: 'AFRWRWRW' },
  { name: 'Bank of Kigali Plc', code: 'BKIGRWRW' },
  { name: "Banque de l'Habitat du Rwanda", code: 'LHRWRWR1' },
  { name: 'Banque Nationale du Rwanda (BNR)', code: 'BNRWRWRW' },
  { name: 'BPR Bank Rwanda Plc', code: 'BPRWRWRW' },
  { name: 'Crane Bank Rwanda Ltd', code: 'CRRWRWR1' },
  { name: 'Development Bank of Rwanda Plc (BRD)', code: 'BRDRRWRW' },
  { name: 'Ecobank Rwanda Ltd', code: 'ECOCRWRW' },
  { name: 'Equity Bank Rwanda Plc', code: 'EQBLRWRW' },
  { name: 'Guaranty Trust Bank (Rwanda) Plc', code: 'GTBIRWRK' },
  { name: 'I&M Bank (Rwanda) Plc', code: 'IMRWRWRW' },
  { name: 'NCBA Bank Rwanda Plc', code: 'CBAFRWRW' },
  { name: 'Urwego Bank Plc', code: 'UOBRRWRW' },
  { name: 'Other / Not Listed', code: '' },
];

function nameForCode(code) {
  if (!code) return '';
  const bank = RWANDA_BANKS.find((b) => b.code === code);
  return bank ? bank.name : code;
}

module.exports = { RWANDA_BANKS, nameForCode };
