class StatementEntry {
  final DateTime date;
  final String title;
  final double debit;  // مستحقات (عليه)
  final double credit; // مدفوعات (له)

  StatementEntry({
    required this.date,
    required this.title,
    required this.debit,
    required this.credit,
  });
}
