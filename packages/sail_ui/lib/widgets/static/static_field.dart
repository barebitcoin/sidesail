import 'package:flutter/material.dart';
import 'package:sail_ui/sail_ui.dart';
import 'package:sail_ui/widgets/core/sail_text.dart';

class StaticActionField extends StatelessWidget {
  final String label;
  final String value;
  final Widget? suffixWidget;

  const StaticActionField({
    super.key,
    required this.label,
    required this.value,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SailStyleValues.padding20,
        vertical: SailStyleValues.padding10,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: SailText.primary14(label),
          ),
          SailText.primary14(value),
          Expanded(child: Container()),
          if (suffixWidget != null) suffixWidget!,
        ],
      ),
    );
  }
}
