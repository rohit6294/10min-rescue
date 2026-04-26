import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class IntakeChecklistScreen extends StatefulWidget {
  final String requestId;
  const IntakeChecklistScreen({super.key, required this.requestId});

  @override
  State<IntakeChecklistScreen> createState() => _IntakeChecklistScreenState();
}

class _IntakeChecklistScreenState extends State<IntakeChecklistScreen> {
  final _checklist = [
    _CheckItem('Prepare trauma bay / emergency room', false),
    _CheckItem('Alert emergency physician on duty', false),
    _CheckItem('Ensure blood type O- available', false),
    _CheckItem('Prepare IV lines and oxygen', false),
    _CheckItem('Notify surgical team if needed', false),
    _CheckItem('Prepare intake forms and patient registration', false),
    _CheckItem('Clear pathway to emergency ward', false),
  ];

  int get _doneCount => _checklist.where((c) => c.done).length;
  bool get _allDone => _doneCount == _checklist.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        title: const Text('Intake Preparation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/hospital/track/${widget.requestId}'),
        ),
      ),
      body: Column(
        children: [
          // Progress
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Preparation Progress',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy)),
                    Text('$_doneCount / ${_checklist.length}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _doneCount / _checklist.length,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _allDone ? AppColors.onlineGreen : AppColors.accentBlue,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          // Checklist items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _checklist.length,
              itemBuilder: (context, i) {
                final item = _checklist[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.done
                          ? AppColors.onlineGreen.withValues(alpha: 0.3)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: () =>
                          setState(() => _checklist[i] = item.toggle()),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: item.done
                              ? AppColors.onlineGreen
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: item.done
                                ? AppColors.onlineGreen
                                : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: item.done
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: item.done
                            ? AppColors.textSecondary
                            : AppColors.navy,
                        decoration: item.done
                            ? TextDecoration.lineThrough
                            : null,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () =>
                        setState(() => _checklist[i] = item.toggle()),
                  ),
                );
              },
            ),
          ),

          // Bottom action
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    context.go('/hospital/track/${widget.requestId}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _allDone ? AppColors.onlineGreen : AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _allDone ? '✓ All Prepared! Track Ambulance' : 'Back to Tracking',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem {
  final String label;
  final bool done;
  const _CheckItem(this.label, this.done);
  _CheckItem toggle() => _CheckItem(label, !done);
}
