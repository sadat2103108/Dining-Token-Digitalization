/// Aggregated credit history for a single day.
class DailyCreditHistory {
  final String date;
  final List<CreditTransactionSummary> transactions;

  const DailyCreditHistory({
    required this.date,
    required this.transactions,
  });

  factory DailyCreditHistory.fromJson(Map<String, dynamic> json) {
    return DailyCreditHistory(
      date: json['date'] as String,
      transactions: (json['transactions'] as List<dynamic>?)
              ?.map((e) =>
                  CreditTransactionSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  int get totalAmount =>
      transactions.fold(0, (sum, t) => sum + t.amount);

  int get transactionCount => transactions.length;
}

class CreditTransactionSummary {
  final String id;
  final String studentId;
  final String studentName;
  final int amount;
  final String time;

  const CreditTransactionSummary({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.time,
  });

  factory CreditTransactionSummary.fromJson(Map<String, dynamic> json) {
    return CreditTransactionSummary(
      id: json['id'].toString(),
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String,
      amount: (json['amount'] as num).toInt(),
      time: json['time'] as String,
    );
  }
}
