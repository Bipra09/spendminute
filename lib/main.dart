import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(MaterialApp(
    title: 'SpendMinute',
    theme: ThemeData(colorSchemeSeed: const Color(0xff14574c)),
    home: Ledger(prefs: prefs),
  ));
}

class Expense {
  const Expense(this.label, this.yen, this.time);

  final String label;
  final int yen;
  final DateTime time;

  Map<String, Object> toJson() =>
      {'label': label, 'yen': yen, 'time': time.toIso8601String()};

  factory Expense.fromJson(Map<String, dynamic> data) => Expense(
        data['label'] as String,
        data['yen'] as int,
        DateTime.parse(data['time'] as String),
      );
}

class Ledger extends StatefulWidget {
  const Ledger({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<Ledger> createState() => _LedgerState();
}

class _LedgerState extends State<Ledger> {
  static const storageKey = 'expenses-v1';
  late List<Expense> expenses;
  DateTime day = DateTime.now();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final data = jsonDecode(widget.prefs.getString(storageKey) ?? '[]') as List;
    expenses = data
        .map((row) => Expense.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> addExpense() async {
    final entry = await showDialog<Expense>(
      context: context,
      builder: (_) => const AddExpenseDialog(),
    );
    if (!mounted || entry == null || saving) return;
    setState(() => saving = true);
    try {
      final next = [entry, ...expenses];
      if (!await widget.prefs.setString(storageKey, jsonEncode(next))) {
        throw StateError('Write failed');
      }
      if (mounted) setState(() {
        expenses = next;
        day = entry.time;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this expense.')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = expenses.where((e) => DateUtils.isSameDay(e.time, day)).toList();
    final groups = <int, List<Expense>>{};
    for (final expense in entries) {
      groups.putIfAbsent(expense.time.hour, () => []).add(expense);
    }
    final hours = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final total = entries.fold<int>(0, (sum, entry) => sum + entry.yen);
    return Scaffold(
      appBar: AppBar(title: const Text('SpendMinute'), actions: [
        IconButton(
          tooltip: 'Calculator',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const Calculator()),
          ),
          icon: const Icon(Icons.calculate_outlined),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: saving ? null : addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
        ListTile(
          title: Text(MaterialLocalizations.of(context).formatFullDate(day)),
          subtitle: Text('Daily total ¥$total'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final picked = await showDatePicker(
              context: context, initialDate: day,
              firstDate: DateTime(2000), lastDate: DateTime.now(),
            );
            if (mounted && picked != null) setState(() => day = picked);
          },
        ),
        if (hours.isEmpty) const ListTile(title: Text('No expenses for this day.')),
        for (final hour in hours) ...[
          ListTile(
            title: Text('${hour.toString().padLeft(2, '0')}:00'),
            trailing: Text('¥${groups[hour]!.fold<int>(0, (sum, e) => sum + e.yen)}'),
          ),
          for (final e in groups[hour]!)
            ListTile(
              leading: Text(e.time.minute.toString().padLeft(2, '0')),
              title: Text(e.label),
              trailing: Text('¥${e.yen}'),
            ),
        ],
      ]),
    );
  }
}

class AddExpenseDialog extends StatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final form = GlobalKey<FormState>();
  final label = TextEditingController();
  final amount = TextEditingController();

  @override
  void dispose() {
    label.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add expense'),
    content: Form(
      key: form,
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: label, maxLength: 80,
            decoration: const InputDecoration(labelText: 'Description'),
            validator: (value) => value!.trim().isEmpty ? 'Enter a description' : null,
          ),
          TextFormField(
            controller: amount,
            decoration: const InputDecoration(labelText: 'Amount (¥)'),
            keyboardType: TextInputType.number,
            validator: (value) {
              final yen = int.tryParse(value!.trim());
              return yen == null || yen < 1 || yen > 100000000
                  ? 'Enter a whole amount from 1 to 100,000,000' : null;
            },
          ),
        ]),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () {
        if (form.currentState!.validate()) {
          Navigator.pop(context, Expense(label.text.trim(), int.parse(amount.text.trim()), DateTime.now()));
        }
      }, child: const Text('Save')),
    ],
  );
}

class Calculator extends StatefulWidget {
  const Calculator({super.key});

  @override
  State<Calculator> createState() => _CalculatorState();
}

class _CalculatorState extends State<Calculator> {
  final left = TextEditingController();
  final right = TextEditingController();
  String result = '';

  void calculate(String operator) {
    final a = double.tryParse(left.text.trim());
    final b = double.tryParse(right.text.trim());
    if (a == null || b == null || !a.isFinite || !b.isFinite) {
      setState(() => result = 'Enter two numbers.');
      return;
    }
    if (operator == '÷' && b == 0) {
      setState(() => result = 'Cannot divide by zero.');
      return;
    }
    final value = switch (operator) {
      '+' => a + b,
      '−' => a - b,
      '×' => a * b,
      _ => a / b,
    };
    setState(() => result = value.isFinite ? value.toStringAsPrecision(12) : 'Result is out of range.');
  }

  @override
  void dispose() {
    left.dispose();
    right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calculator')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      for (final (label, controller) in [('First number', left), ('Second number', right)])
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [
        for (final operator in ['+', '−', '×', '÷'])
          FilledButton(onPressed: () => calculate(operator), child: Text(operator)),
      ]),
      const SizedBox(height: 16),
      Semantics(liveRegion: true, child: Text(result)),
    ]),
  );
}
