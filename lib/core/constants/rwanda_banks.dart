/// A commercial bank licensed to operate in Rwanda, identified by its
/// SWIFT/BIC code — the same code used to route both local (RTGS/EFT) and
/// international bank transfers. Selecting a bank by its verified code
/// instead of a free-typed name is what prevents payroll transfers from
/// silently going to the wrong institution because of a misspelled or
/// inconsistent bank name.
class RwandaBank {
  const RwandaBank(this.name, this.code);
  final String name;
  final String code;
}

/// Commercial banks licensed by the National Bank of Rwanda (BNR), with
/// their head-office SWIFT/BIC codes. Sourced and cross-checked against two
/// independent SWIFT-code registries (theswiftcodes.com and wewire.com) —
/// both list the same 17 banks and codes.
///
/// Microfinance banks without a public SWIFT registration (e.g. Zigama CSS,
/// Unguka Bank) aren't included here since there's no verifiable code to
/// select — such accounts should be entered under "Other".
class RwandaBanks {
  RwandaBanks._();

  static const List<RwandaBank> all = [
    RwandaBank('AB Bank Rwanda Plc', 'ABBRRWRW'),
    RwandaBank('Access Bank (Rwanda) Plc', 'BKORRWRW'),
    RwandaBank('Bank of Africa Rwanda Ltd', 'AFRWRWRW'),
    RwandaBank('Bank of Kigali Plc', 'BKIGRWRW'),
    RwandaBank('Banque de l\'Habitat du Rwanda', 'LHRWRWR1'),
    RwandaBank('Banque Nationale du Rwanda (BNR)', 'BNRWRWRW'),
    RwandaBank('BPR Bank Rwanda Plc', 'BPRWRWRW'),
    RwandaBank('Crane Bank Rwanda Ltd', 'CRRWRWR1'),
    RwandaBank('Development Bank of Rwanda Plc (BRD)', 'BRDRRWRW'),
    RwandaBank('Ecobank Rwanda Ltd', 'ECOCRWRW'),
    RwandaBank('Equity Bank Rwanda Plc', 'EQBLRWRW'),
    RwandaBank('Guaranty Trust Bank (Rwanda) Plc', 'GTBIRWRK'),
    RwandaBank('I&M Bank (Rwanda) Plc', 'IMRWRWRW'),
    RwandaBank('NCBA Bank Rwanda Plc', 'CBAFRWRW'),
    RwandaBank('Urwego Bank Plc', 'UOBRRWRW'),
    RwandaBank('Other / Not Listed', ''),
  ];

  static String nameForCode(String? code) {
    if (code == null || code.isEmpty) return '';
    for (final b in all) {
      if (b.code == code) return b.name;
    }
    return code;
  }
}
