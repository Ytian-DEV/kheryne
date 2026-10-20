import 'package:flutter/material.dart';

/// Genus names are always italic. Use this instead of a raw [Text].
class GenusName extends StatelessWidget {
  const GenusName(this.name, {super.key, this.style, this.maxLines = 2, this.textAlign});

  final String name;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text(
      name,
      style: base.copyWith(fontStyle: FontStyle.italic),
      maxLines: maxLines,
      softWrap: true,
      overflow: TextOverflow.visible,
      textAlign: textAlign,
    );
  }
}

/// Inline italic genus inside running text: `genusSpan('Pratylenchus')`.
TextSpan genusSpan(String name, {TextStyle? style}) =>
    TextSpan(text: name, style: (style ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic));
