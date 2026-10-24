import 'dart:math' show min, max;

enum TxType { income, expense, transfer }

enum Freq { daily, weekly, monthly, yearly }

extension FreqX on Freq {
  String get label => switch (this) {
        Freq.daily => 'Harian',
        Freq.weekly => 'Mingguan',
        Freq.monthly => 'Bulanan',
        Freq.yearly => 'Tahunan',
      };
}

typedef DbMap = Map<String, Object?>;

int _i(Object? v) => (v as num).toInt();
double _d(Object? v) => (v as num).toDouble();
DateTime _dt(Object? v) => DateTime.fromMillisecondsSinceEpoch(_i(v));
DateTime? _dtn(Object? v) => v == null ? null : _dt(v);

DateTime nextOccurrence(DateTime d, Freq f, int anchorDay) {
  switch (f) {
    case Freq.daily:
      return DateTime(d.year, d.month, d.day + 1);
    case Freq.weekly:
      return DateTime(d.year, d.month, d.day + 7);
    case Freq.monthly:
      final y = d.year + (d.month == 12 ? 1 : 0);
      final m = d.month % 12 + 1;
      final dim = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, min(anchorDay, dim));
    case Freq.yearly:
      final y = d.year + 1;
      final dim = DateTime(y, d.month + 1, 0).day;
      return DateTime(y, d.month, min(anchorDay, dim));
  }
}

class Wallet {
  Wallet({
    required this.id,
    required this.name,
    this.type = 'cash',
    this.initial = 0,
    required this.color,
    required this.icon,
    this.archived = false,
    this.sort = 0,
  });
  String id;
  String name;
  String type;
  double initial;
  int color;
  int icon;
  bool archived;
  int sort;

  DbMap toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'initial': initial,
        'color': color,
        'icon': icon,
        'archived': archived ? 1 : 0,
        'sort': sort,
      };
  factory Wallet.fromMap(DbMap m) => Wallet(
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        initial: _d(m['initial']),
        color: _i(m['color']),
        icon: _i(m['icon']),
        archived: _i(m['archived']) == 1,
        sort: _i(m['sort']),
      );
}

class Cat {
  Cat({required this.id, required this.name, required this.isExpense, required this.color, required this.icon});
  String id;
  String name;
  bool isExpense;
  int color;
  int icon;

  DbMap toMap() => {'id': id, 'name': name, 'is_expense': isExpense ? 1 : 0, 'color': color, 'icon': icon};
  factory Cat.fromMap(DbMap m) => Cat(
        id: m['id'] as String,
        name: m['name'] as String,
        isExpense: _i(m['is_expense']) == 1,
        color: _i(m['color']),
        icon: _i(m['icon']),
      );
}

class Tx {
  Tx({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    this.toWalletId,
    this.categoryId,
    required this.date,
    this.note = '',
    this.recurringId,
    this.externalId,
    this.neutral = false,
    DateTime? created,
  }) : created = created ?? DateTime.now();
  String id;
  TxType type;
  double amount;
  String walletId;
  String? toWalletId;
  String? categoryId;
  DateTime date;
  String note;
  String? recurringId;
  String? externalId; // impor CSV (hash) atau tautan hutang: 'debt:<id>' / 'pay:<id>'
  bool neutral; // arus hutang/piutang: mengubah saldo dompet tetapi bukan pemasukan/pengeluaran
  DateTime created;

  DbMap toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'wallet_id': walletId,
        'to_wallet_id': toWalletId,
        'category_id': categoryId,
        'date': date.millisecondsSinceEpoch,
        'note': note,
        'recurring_id': recurringId,
        'external_id': externalId,
        'neutral': neutral ? 1 : 0,
        'created': created.millisecondsSinceEpoch,
      };
  factory Tx.fromMap(DbMap m) => Tx(
        id: m['id'] as String,
        type: TxType.values.byName(m['type'] as String),
        amount: _d(m['amount']),
        walletId: m['wallet_id'] as String,
        toWalletId: m['to_wallet_id'] as String?,
        categoryId: m['category_id'] as String?,
        date: _dt(m['date']),
        note: (m['note'] as String?) ?? '',
        recurringId: m['recurring_id'] as String?,
        externalId: m['external_id'] as String?,
        neutral: (m['neutral'] as num?)?.toInt() == 1,
        created: _dt(m['created']),
      );
}

class Budget {
  Budget({required this.id, required this.categoryId, required this.amount, this.rolloverFrom});
  String id;
  String categoryId;
  double amount;
  DateTime? rolloverFrom; // awal bulan saat rollover diaktifkan (null = nonaktif)

  DbMap toMap() => {
        'id': id,
        'category_id': categoryId,
        'amount': amount,
        'rollover_from': rolloverFrom?.millisecondsSinceEpoch,
      };
  factory Budget.fromMap(DbMap m) => Budget(
        id: m['id'] as String,
        categoryId: m['category_id'] as String,
        amount: _d(m['amount']),
        rolloverFrom: _dtn(m['rollover_from']),
      );
}

/// Batas efektif dengan rollover: sisa tiap bulan (tidak negatif) terbawa ke bulan berikutnya.
/// [spentOldestFirst] = pengeluaran per bulan dari bulan rollover dimulai sampai bulan sebelum bulan target.
double rolloverLimit(double base, List<double> spentOldestFirst) {
  var carry = 0.0;
  for (final spent in spentOldestFirst) {
    final limit = base + carry;
    carry = max(0.0, limit - spent);
  }
  return base + carry;
}

class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.target,
    this.saved = 0,
    this.deadline,
    required this.color,
    this.icon = 10,
  });
  String id;
  String name;
  double target;
  double saved;
  DateTime? deadline;
  int color;
  int icon;

  DbMap toMap() => {
        'id': id,
        'name': name,
        'target': target,
        'saved': saved,
        'deadline': deadline?.millisecondsSinceEpoch,
        'color': color,
        'icon': icon,
      };
  factory Goal.fromMap(DbMap m) => Goal(
        id: m['id'] as String,
        name: m['name'] as String,
        target: _d(m['target']),
        saved: _d(m['saved']),
        deadline: _dtn(m['deadline']),
        color: _i(m['color']),
        icon: _i(m['icon']),
      );
}

class Recurring {
  Recurring({
    required this.id,
    required this.type,
    required this.amount,
    required this.walletId,
    this.toWalletId,
    this.categoryId,
    this.note = '',
    required this.freq,
    required this.nextDate,
    this.endDate,
    required this.anchorDay,
    this.active = true,
  });
  String id;
  TxType type;
  double amount;
  String walletId;
  String? toWalletId;
  String? categoryId;
  String note;
  Freq freq;
  DateTime nextDate;
  DateTime? endDate;
  int anchorDay;
  bool active;

  DbMap toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'wallet_id': walletId,
        'to_wallet_id': toWalletId,
        'category_id': categoryId,
        'note': note,
        'freq': freq.name,
        'next_date': nextDate.millisecondsSinceEpoch,
        'end_date': endDate?.millisecondsSinceEpoch,
        'anchor_day': anchorDay,
        'active': active ? 1 : 0,
      };
  factory Recurring.fromMap(DbMap m) => Recurring(
        id: m['id'] as String,
        type: TxType.values.byName(m['type'] as String),
        amount: _d(m['amount']),
        walletId: m['wallet_id'] as String,
        toWalletId: m['to_wallet_id'] as String?,
        categoryId: m['category_id'] as String?,
        note: (m['note'] as String?) ?? '',
        freq: Freq.values.byName(m['freq'] as String),
        nextDate: _dt(m['next_date']),
        endDate: _dtn(m['end_date']),
        anchorDay: _i(m['anchor_day']),
        active: _i(m['active']) == 1,
      );
}

class DebtPayment {
  DebtPayment({required this.id, required this.debtId, required this.amount, required this.date, this.note = ''});
  String id;
  String debtId;
  double amount;
  DateTime date;
  String note;

  DbMap toMap() => {
        'id': id,
        'debt_id': debtId,
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };
  factory DebtPayment.fromMap(DbMap m) => DebtPayment(
        id: m['id'] as String,
        debtId: m['debt_id'] as String,
        amount: _d(m['amount']),
        date: _dt(m['date']),
        note: (m['note'] as String?) ?? '',
      );
}

class Debt {
  Debt({
    required this.id,
    required this.person,
    required this.amount,
    required this.owedToMe,
    this.due,
    this.note = '',
    DateTime? created,
    this.settled = false,
  }) : created = created ?? DateTime.now();
  String id;
  String person;
  double amount;
  bool owedToMe; // true = piutang (orang lain berutang ke saya)
  DateTime? due;
  String note;
  DateTime created;
  bool settled;
  List<DebtPayment> payments = [];

  double get paid => payments.fold(0.0, (a, p) => a + p.amount);
  double get remaining => max(0.0, amount - paid);

  DbMap toMap() => {
        'id': id,
        'person': person,
        'amount': amount,
        'owed_to_me': owedToMe ? 1 : 0,
        'due': due?.millisecondsSinceEpoch,
        'note': note,
        'created': created.millisecondsSinceEpoch,
        'settled': settled ? 1 : 0,
      };
  factory Debt.fromMap(DbMap m) => Debt(
        id: m['id'] as String,
        person: m['person'] as String,
        amount: _d(m['amount']),
        owedToMe: _i(m['owed_to_me']) == 1,
        due: _dtn(m['due']),
        note: (m['note'] as String?) ?? '',
        created: _dt(m['created']),
        settled: _i(m['settled']) == 1,
      );
}

/// Bagian tiap teman dalam patungan (dibulatkan ke bawah); sisa pembulatan ditanggung pembayar.
double splitEach(double total, int people) => people <= 0 ? 0 : (total / people).floorToDouble();
