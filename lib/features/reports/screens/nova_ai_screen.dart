import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../providers/reports_provider.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/app_icon.dart';

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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Nova AI', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: context.appText, letterSpacing: -0.3)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withAlpha(24),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text('BETA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryBlue, letterSpacing: 0.4)),
                        ),
                      ]),
                      Text('Your HR assistant, grounded in your company\'s live data', style: TextStyle(fontSize: 12, color: context.appSubtext)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
              boxShadow: [BoxShadow(color: AppColors.primaryBlue.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: const AppIcon(AppIcons.autoAwesomeRounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 16),
          Text('Ask Nova anything', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.appText)),
          const SizedBox(height: 6),
          Text(
            'Ask about attendance, leaves, performance, or payroll.\nNova uses your company\'s real-time data.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.appSubtext, height: 1.6),
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 4.2,
              children: _suggestions.map((s) => _SuggestionCard(text: s, onTap: onSuggestion)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String text;
  final ValueChanged<String> onTap;
  const _SuggestionCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(text),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: context.cardDeco(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AppColors.warningAmber.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AppIcon(AppIcons.lightbulbOutlineRounded, size: 13, color: AppColors.warningAmber),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text,
                style: TextStyle(fontSize: 12.5, color: context.appText, fontWeight: FontWeight.w500, height: 1.3))),
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
            child: const AppIcon(AppIcons.autoAwesomeRounded, color: Colors.white, size: 16),
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
              child: MarkdownBody(
                data: message.text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: context.appText, fontSize: 13, height: 1.6),
                  strong: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
                  listBullet: TextStyle(color: context.appText, fontSize: 13),
                ),
              ),
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
            child: const AppIcon(AppIcons.autoAwesomeRounded, color: Colors.white, size: 16),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: context.appBg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(context.isDark ? 40 : 12), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.appBorder),
                ),
                child: Center(
                  child: TextField(
                    controller: controller,
                    enabled: !loading,
                    style: TextStyle(fontSize: 13, color: context.appText),
                    decoration: InputDecoration(
                      hintText: 'Ask Nova about your HR data…',
                      hintStyle: TextStyle(color: context.appSubtext, fontSize: 13),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    onSubmitted: loading ? null : onSend,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: loading ? context.alternate : context.tertiary,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                onTap: loading ? null : () => onSend(controller.text),
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const AppIcon(AppIcons.sendRounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
