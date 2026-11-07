// The Notevia UI kit. Pages import this one file.
export '../theme/tokens.dart';
export 'activity_calendar.dart';
export 'box.dart';
export 'buttons.dart';
export 'code_field.dart';
export 'fields.dart';
export 'google_button.dart';
export 'logo.dart';
export 'markdown_editor.dart';
export 'markdown_view.dart';
export 'mood.dart';
export 'pin_pad.dart';
export 'states.dart';

import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'logo.dart';

/// Shared scaffold for the sign-in / sign-up / PIN screens:
/// a narrow, top-aligned column with the mark, a heading and one line under it.
class NvAuthLayout extends StatelessWidget {
  const NvAuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.header,
    this.footer,
    this.scroll = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? leading;

  /// Replaces the default mark above the title
  final Widget? header;
  final Widget? footer;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NvSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: leading == null ? NvSpace.xxl : NvSpace.md),
              Align(alignment: Alignment.centerLeft, child: header ?? _DefaultMark()),
              const SizedBox(height: NvSpace.lg),
              Text(title, style: NvText.display.copyWith(color: c.fg)),
              if (subtitle != null) ...[
                const SizedBox(height: NvSpace.xs),
                Text(subtitle!, style: NvText.small.copyWith(color: c.muted)),
              ],
              const SizedBox(height: NvSpace.xl),
              child,
              if (footer != null) ...[const SizedBox(height: NvSpace.lg), footer!],
              const SizedBox(height: NvSpace.xl),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: leading == null
          ? null
          : AppBar(leading: leading, automaticallyImplyLeading: false),
      body: SafeArea(
        top: leading == null,
        child: scroll
            ? SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Align(alignment: Alignment.topCenter, child: body),
              )
            : body,
      ),
    );
  }
}

class _DefaultMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const NvMark(size: 40);
}

/// "New to Notevia? Create an account" — the bordered box under a form.
class NvAuthSwitch extends StatelessWidget {
  const NvAuthSwitch({super.key, required this.prompt, required this.action, required this.onTap});
  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NvSpace.md, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(NvRadius.control),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(prompt, style: NvText.small.copyWith(color: c.muted))),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
