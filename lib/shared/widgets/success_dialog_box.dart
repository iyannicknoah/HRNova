import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/app_colors.dart';

class SuccessDialogBoxWidget extends StatefulWidget {
  const SuccessDialogBoxWidget({
    super.key,
    String? message,
  }) : this.message = message ?? 'Success message!';

  final String message;

  @override
  State<SuccessDialogBoxWidget> createState() => _SuccessDialogBoxWidgetState();
}

class _SuccessDialogBoxWidgetState extends State<SuccessDialogBoxWidget> {
  @override
  void initState() {
    super.initState();

    // Auto-dismiss dialog after 2000 milliseconds
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: const Alignment(0, 0),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardNavy : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Triple Nested Circle Blue Checkmark Indicator (Matches Screenshot 2)
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Align(
                      alignment: const Alignment(0, 0),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0x2810B981), // Soft outer green
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0x5310B981), // Medium middle green
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, 0),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // Solid inner green
                          shape: BoxShape.circle,
                        ),
                        child: const Align(
                          alignment: Alignment(0, 0),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.darkNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
