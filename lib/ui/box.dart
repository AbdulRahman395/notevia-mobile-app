import 'package:flutter/material.dart';
import '../theme/tokens.dart';

/// Primer "Box": one bordered container whose rows are split by hairlines.
/// The single container recipe of the app — never nested inside another box.
class NvBox extends StatelessWidget {
  const NvBox({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, color: c.lineMuted));
      rows.add(children[i]);
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NvRadius.control),
        border: Border.all(color: c.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// Section heading above a box: body face, a step smaller, sentence case.
class NvSectionHeader extends StatelessWidget {
  const NvSectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, NvSpace.lg, 2, NvSpace.xs),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: NvText.label.copyWith(color: context.nv.fg),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A tappable row inside a box.
class NvRow extends StatelessWidget {
  const NvRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    final titleColor = destructive ? c.danger : c.fg;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NvSpace.md,
              vertical: NvSpace.sm,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(leading, size: 20, color: destructive ? c.danger : c.muted),
                  const SizedBox(width: NvSpace.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: NvText.body.copyWith(color: titleColor, height: 1.3)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: NvText.meta.copyWith(color: c.muted)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: NvSpace.sm),
                  trailing!,
                ],
                if (showChevron) ...[
                  const SizedBox(width: NvSpace.xs),
                  Icon(Icons.chevron_right, size: 20, color: c.subtle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row with a switch on the right (the whole row toggles it).
class NvSwitchRow extends StatelessWidget {
  const NvSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool busy;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: NvRow(
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null || busy ? null : () => onChanged!(!value),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// One option of a single-choice group.
class NvRadioRow<T> extends StatelessWidget {
  const NvRadioRow({
    super.key,
    required this.title,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final T value;
  final bool selected;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.nv;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onSelected == null ? null : () => onSelected!(value),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NvSpace.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title, style: NvText.body.copyWith(color: c.fg)),
                  ),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: NvMotion.of(context, NvMotion.micro),
                    child: Icon(Icons.check, size: 20, color: c.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
