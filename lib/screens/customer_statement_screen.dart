import "package:flutter/material.dart";
import "../repo.dart";
import "../utils.dart";
import "../statement_export.dart";

class CustomerStatementScreen extends StatefulWidget {
  final int customerId;
  const CustomerStatementScreen({super.key, required this.customerId});

  @override
  State<CustomerStatementScreen> createState() => _CustomerStatementScreenState();
}

class _CustomerStatementScreenState extends State<CustomerStatementScreen> {
  bool loading = true;
  String customerName = "";
  List<Map<String, Object?>> ledger = [];

  double debit = 0;
  double credit = 0;
  double balance = 0; // debit - credit

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _balanceDelta(String type, double amount) {
    // balance = debit - credit
    // debit increases balance (+)
    // credit decreases balance (-)
    switch (type) {
      case "order":
      case "expense":
        return amount; // debit
      case "payment":
        return -amount; // credit
      case "cash":
        // amount + => cash in (credit) -> reduces balance
        // amount - => cash out (debit) -> increases balance automatically because -(-x)=+x
        return -amount;
      default:
        return 0;
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final c = await Repo.instance.getCustomer(widget.customerId);
    final rows = await Repo.instance.customerLedger(widget.customerId);

    double d = 0;
    double cr = 0;

    for (final r in rows) {
      final type = r["type"] as String;
      final amount = (r["amount"] as double);

      if (type == "order" || type == "expense") {
        d += amount;
      } else if (type == "payment") {
        cr += amount;
      } else if (type == "cash") {
        // cash + => credit, cash - => debit
        if (amount >= 0) cr += amount; else d += (-amount);
      }
    }

    setState(() {
      customerName = c.name;
      ledger = rows;
      debit = d;
      credit = cr;
      balance = d - cr;
      loading = false;
    });
  }

  String _fmtDateTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return "${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}";
  }

  String _titleFor(Map<String, Object?> r) {
    final type = r["type"] as String;
    final orderId = r["order_id"];
    final amount = (r["amount"] as double);

    switch (type) {
      case "order":
        return "أوردر مُسلّم #$orderId";
      case "payment":
        return "دفعة ${orderId == null ? "(تحت الحساب)" : "على أوردر #$orderId"}";
      case "expense":
        return "مصروف ${orderId == null ? "" : "(أوردر #$orderId)"}";
      case "cash":
        return "حركة خزنة ${amount >= 0 ? "(دخل)" : "(صرف)"} ${orderId == null ? "" : "— أوردر #$orderId"}";
      default:
        return "حركة";
    }
  }

  bool _isDebit(Map<String, Object?> r) {
    final type = r["type"] as String;
    final amount = (r["amount"] as double);

    if (type == "order" || type == "expense") return true;
    if (type == "payment") return false;
    if (type == "cash") return amount < 0; // cash out = debit
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("كشف حساب: $customerName"),
        actions: [
          IconButton(
            tooltip: "تحديث",
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: "تصدير HTML",
            icon: const Icon(Icons.description_outlined),
            onPressed: ledger.isEmpty
                ? null
                : () async {
                    final path = await StatementExporter.exportHtml(
                      customerName: customerName,
                      ledger: ledger,
                      debit: debit,
                      credit: credit,
                      balance: balance,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("تم تصدير الملف ✅\n$path")),
                    );
                  },
          ),
          IconButton(
            tooltip: "إرسال",
            icon: const Icon(Icons.share),
            onPressed: ledger.isEmpty
                ? null
                : () async {
                    final path = await StatementExporter.exportHtml(
                      customerName: customerName,
                      ledger: ledger,
                      debit: debit,
                      credit: credit,
                      balance: balance,
                    );
                    await StatementExporter.shareFile(path, message: "كشف حساب: $customerName");
                  },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _row("إجمالي مدين (طلبات/مصروفات)", debit),
                          const SizedBox(height: 6),
                          _row("إجمالي دائن (مدفوعات/دخل خزنة)", credit),
                          const Divider(),
                          _row("الرصيد", balance, bold: true),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ledger.isEmpty
                      ? const Center(child: Text("لا توجد حركات"))
                      : ListView.separated(
                          itemCount: ledger.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final r = ledger[i];
                            final amount = (r["amount"] as double);
                            final note = ((r["note"] ?? "") as String).trim();
                            final date = _fmtDateTime(r["created_at"] as int);

                            // running balance
                            double running = 0;
                            for (int k = 0; k <= i; k++) {
                              final rr = ledger[k];
                              final tt = rr["type"] as String;
                              final aa = (rr["amount"] as double);
                              running += _balanceDelta(tt, aa);
                            }

                            final isDebit = _isDebit(r);
                            final title = _titleFor(r);

                            // display amount sign:
                            // - cash: keep natural sign for clarity
                            final displayAmount = (r["type"] == "cash")
                                ? "${amount >= 0 ? "+" : "-"}${fmtMoney(amount.abs())}"
                                : "${isDebit ? "+" : "-"}${fmtMoney(amount)}";

                            return ListTile(
                              isThreeLine: true,
                              title: Text(title),
                              subtitle: Text(
                                "$date${note.isEmpty ? "" : "  •  $note"}\nالرصيد بعد الحركة: ${fmtMoney(running)} EGP",
                              ),
                              trailing: Text(
                                "$displayAmount EGP",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDebit ? Colors.red : Colors.green,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _row(String t, double v, {bool bold = false}) {
    return Row(
      children: [
        Expanded(child: Text(t, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600))),
        Text("${fmtMoney(v)} EGP", style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}
