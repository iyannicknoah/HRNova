import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../providers/reports_provider.dart';

// ── Standalone screen (route: /nova-ai) ──────────────────────────────────────
class NovaAiScreen extends StatelessWidget {
  const NovaAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          Container(
            color: context.appCard,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A9EFF), Color(0xFF43E0C8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.appText)),
                    Text('Your HR assistant', style: TextStyle(fontSize: 12, color: context.appSubtext)),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.appBorder),
          const Expanded(child: NovaAiView()),
        ],
      ),
    );
  }
}

// ── Reusable chat view (used as a tab in ReportsScreen too) ───────────────────
class NovaAiView extends ConsumerStatefulWidget {
  const NovaAiView({super.key});

  @override
  ConsumerState<NovaAiView> createState() => _NovaAiViewState();
}

class _NovaAiViewState extends ConsumerState<NovaAiView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(novaAiProvider.notifier).ask(text.trim());
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(novaAiProvider);
    ref.listen<NovaAiState>(novaAiProvider, (_, next) {
      if (!next.loading) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Column(
      children: [
        Expanded(
          child: state.messages.isEmpty
              ? _EmptyState(onSuggestion: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length + (state.loading ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == state.messages.length) return _TypingIndicator();
                    final msg = state.messages[i];
                    return _Bubble(message: msg);
                  },
                ),
        ),
        _InputBar(controller: _controller, onSend: _send, loading: state.loading),
      ],
    );
  }
}

// ── Empty state with suggestion chips ─────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestion;
  const _EmptyState({required this.onSuggestion});

  static const _suggestions = [
    'How many employees are present today?',
    'How many pending leave requests do we have?',
    'What is the average performance score this month?',
    'Which department has the lowest attendance?',
    'How many active employees do we have?',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A9EFF), Color(0xFF43E0C8)]),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(50), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text('Ask Nova anything', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.appText)),
          const SizedBox(height: 6),
          Text(
            'Ask about attendance, leaves, performance, or payroll.\nNova uses your company\'s real-time data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.appSubtext, height: 1.6),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _suggestions.map((s) => _SuggestionChip(text: s, onTap: onSuggestion)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final ValueChanged<String> onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(text),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.appBorder),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb_outline_rounded, size: 13, color: AppColors.warningAmber),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: TextStyle(fontSize: 12, color: context.appText, fontWeight: FontWeight.w500))),
          ],
        ),
      ),
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF4A9EFF), Color(0xFF2979E0)]),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(message.text, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A9EFF), Color(0xFF43E0C8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, right: 60),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: context.appBorder),
              ),
              child: Text(message.text, style: TextStyle(color: context.appText, fontSize: 13, height: 1.6)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    _anim = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A9EFF), Color(0xFF43E0C8)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: context.appBorder),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context2, child2) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final delay = i / 3.0;
                  final phase = (_anim.value - delay).clamp(0.0, 1.0);
                  final opacity = (phase < 0.5 ? phase * 2 : (1 - phase) * 2).clamp(0.3, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool loading;
  const _InputBar({required this.controller, required this.onSend, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        color: context.appCard,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !loading,
              style: TextStyle(fontSize: 13, color: context.appText),
              decoration: InputDecoration(
                hintText: 'Ask Nova about your HR data...',
                hintStyle: TextStyle(color: context.appSubtext, fontSize: 13),
                filled: true,
                fillColor: context.appField,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.appBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                ),
              ),
              onSubmitted: loading ? null : onSend,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: loading ? context.appBorder : AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: loading ? null : () => onSend(controller.text),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
