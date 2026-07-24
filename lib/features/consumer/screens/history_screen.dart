import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';
import 'installment_details_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _sortBy = 'urgency'; // default
  String _filter = 'All'; // 'All', 'Everyday', 'Assets'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              icon: const Icon(Icons.sort, color: Colors.black, size: 20),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              items: const [
                DropdownMenuItem(value: 'name', child: Text('Name')),
                DropdownMenuItem(
                  value: 'total debt',
                  child: Text('Total Debt'),
                ),
                DropdownMenuItem(
                  value: 'installment debt',
                  child: Text('Installment Debt'),
                ),
                DropdownMenuItem(
                  value: 'installment duration',
                  child: Text('Duration'),
                ),
                DropdownMenuItem(value: 'urgency', child: Text('Urgency')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _sortBy = val;
                  });
                }
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<InstallmentRow>>(
        stream: DatabaseService.consumerInstallments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? const <InstallmentRow>[];
          final paidInstallments = rows.where((inst) {
            if (!inst.isCompleted) return false;
            if (_filter == 'Everyday') return !inst.isLongTerm;
            if (_filter == 'Assets') return inst.isLongTerm;
            return true;
          }).toList();

          Widget bodyContent;
          if (paidInstallments.isEmpty) {
            if (_filter == 'All') {
              bodyContent = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No payment history yet.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fully paid installments will appear here.',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  ],
                ),
              );
            } else {
              bodyContent = Center(
                child: Text(
                  'No paid ${(_filter == 'Assets') ? 'long-term assets' : 'everyday installments'} found.',
                  style: const TextStyle(color: Colors.grey),
                ),
              );
            }
          } else {
            // Sort the paid installments
            paidInstallments.sort((a, b) {
              switch (_sortBy) {
                case 'name':
                  return a.merchantName.toLowerCase().compareTo(
                    b.merchantName.toLowerCase(),
                  );
                case 'total debt':
                  return b.totalAmount.compareTo(
                    a.totalAmount,
                  ); // descending original debt
                case 'installment debt':
                  return b.monthlyPayment.compareTo(
                    a.monthlyPayment,
                  ); // descending
                case 'installment duration':
                  return b.totalMonths.compareTo(a.totalMonths); // descending
                case 'urgency':
                default:
                  return b.dueDate.compareTo(
                    a.dueDate,
                  ); // descending (latest paid/due first)
              }
            });

            final currencyFormatter = NumberFormat.currency(
              symbol: 'EGP ',
              decimalDigits: 0,
            );

            bodyContent = ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: paidInstallments.length,
              itemBuilder: (context, index) {
                var inst = paidInstallments[index];

                return CardPopIn(
                  id: inst.id,
                  builder: (context, animate) => GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InstallmentDetailsScreen(installment: inst),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inst.merchantName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (inst.itemDescription.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      inst.itemDescription,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currencyFormatter.format(inst.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FULLY PAID',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ).popInIf(animate, 0),
                    ),
                  ),
                );
              },
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Wrap(
                  spacing: 8,
                  children: ['All', 'Everyday', 'Assets'].map((
                    String filterName,
                  ) {
                    return FilterChip(
                      label: Text(filterName),
                      selected: _filter == filterName,
                      onSelected: (bool selected) {
                        setState(() {
                          _filter = filterName;
                        });
                      },
                      selectedColor: Colors.blue[100],
                      checkmarkColor: Colors.blue[800],
                      labelStyle: TextStyle(
                        color: _filter == filterName
                            ? Colors.blue[800]
                            : Colors.black87,
                        fontWeight: _filter == filterName
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(child: bodyContent),
            ],
          );
        },
      ),
    );
  }
}
