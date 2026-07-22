/// Bank account number checks for payroll bank transfers.
///
/// Rwanda has no IBAN scheme and no national account-number standard — each
/// bank sets its own length and structure, and almost none publish it. So the
/// checks here are split by how certain they are:
///
///  * [BankAccountCheck.error] — format-agnostic junk that is wrong for every
///    bank (letters, absurd lengths, placeholder digits). Safe to block.
///  * [BankAccountCheck.warning] — bank-specific rules we only partially know.
///    Surfaced but never blocking: this is payroll, and a wrong rule here would
///    stop a real salary. Only Bank of Kigali and Equity have any documented
///    format at all; every other bank is accepted as-is.
library;

/// SWIFT codes of the only two banks with a documented account format.
const String kBankOfKigaliCode = 'BKIGRWRW';
const String kEquityRwandaCode = 'EQBLRWRW';

/// Bank of Kigali: 15 digits — a 5-digit branch code then a 10-digit account.
const int _bkLength = 15;

/// Equity Bank Rwanda: account numbers begin with this prefix. The length is
/// not publicly documented, so it is deliberately not checked.
const String _equityPrefix = '40';

/// Widest plausible account length across banks. Anything outside this is a
/// typo or a pasted phone number rather than a real account, whichever bank
/// it belongs to.
const int _minLength = 5;
const int _maxLength = 20;

class BankAccountCheck {
  const BankAccountCheck({this.error, this.warning});

  /// Certainly invalid — blocks saving.
  final String? error;

  /// Looks wrong for the selected bank, but our format knowledge is partial,
  /// so the user can save anyway after confirming.
  final String? warning;

  bool get hasError => error != null;
  bool get hasWarning => warning != null;
  bool get isClean => error == null && warning == null;
}

/// Checks [accountNumber] against universal rules, plus [bankCode]-specific
/// rules when the bank is one we have a documented format for.
///
/// An empty account number is not an error — bank details are optional until
/// the employee needs to be paid by transfer.
BankAccountCheck checkBankAccount(String? accountNumber, String? bankCode) {
  final value = (accountNumber ?? '').trim();
  if (value.isEmpty) return const BankAccountCheck();

  // ── Tier 1 — true for every bank ────────────────────────────────────────
  if (!RegExp(r'^\d+$').hasMatch(value)) {
    return const BankAccountCheck(
        error: 'Bank account number must contain digits only');
  }
  if (value.length < _minLength || value.length > _maxLength) {
    return const BankAccountCheck(
        error: 'Bank account number must be between 5 and 20 digits');
  }
  if (RegExp(r'^(\d)\1+$').hasMatch(value)) {
    return const BankAccountCheck(
        error: "That doesn't look like a real account number");
  }

  // ── Tier 2 — only the banks whose format is documented ──────────────────
  switch (bankCode) {
    case kBankOfKigaliCode:
      if (value.length != _bkLength) {
        return const BankAccountCheck(
            warning: 'Bank of Kigali accounts are usually 15 digits '
                '(5-digit branch + 10-digit account). Double-check this one.');
      }
    case kEquityRwandaCode:
      if (!value.startsWith(_equityPrefix)) {
        return const BankAccountCheck(
            warning: 'Equity Bank account numbers usually start with 40. '
                'Double-check this one.');
      }
  }

  return const BankAccountCheck();
}
