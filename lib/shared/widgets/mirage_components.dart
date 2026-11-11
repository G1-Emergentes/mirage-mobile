import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/mirage_theme.dart';

class MirageAsset extends StatelessWidget {
  const MirageAsset(this.name, {super.key, this.width, this.height});
  final String name;
  final double? width, height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: name.endsWith('.svg')
        ? SizedBox(
            width: width,
            height: height,
            child: SvgPicture.asset('assets/iam/$name', fit: BoxFit.contain),
          )
        : Image.asset(
            'assets/iam/$name',
            width: width,
            height: height,
            fit: BoxFit.cover,
          ),
  );
}

class MirageWordmark extends StatelessWidget {
  const MirageWordmark({super.key, this.size = 33});
  final double size;
  @override
  Widget build(BuildContext context) => Text(
    'Mirage',
    textScaler: TextScaler.noScaling,
    style: TextStyle(
      fontFamily: 'Lora',
      fontStyle: FontStyle.italic,
      fontSize: size,
      fontWeight: FontWeight.w400,
      height: 1.2,
      color: MirageColors.ink,
    ),
  );
}

class MirageScreen extends StatelessWidget {
  const MirageScreen({
    super.key,
    required this.child,
    this.topPadding = 20,
    this.bottomNavigationBar,
  });
  final Widget child;
  final Widget? bottomNavigationBar;
  final double topPadding;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      minimum: const EdgeInsets.only(top: 48, bottom: 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, topPadding, 24, 20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class MirageHeader extends StatelessWidget {
  const MirageHeader({super.key, this.onBack});
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      if (onBack != null)
        IconButton(
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, size: 22),
        ),
      const Flexible(
        child: FittedBox(fit: BoxFit.scaleDown, child: MirageWordmark()),
      ),
      const MirageAsset('login_imgSparkles.svg', width: 22, height: 22),
    ],
  );
}

class MirageButton extends StatelessWidget {
  const MirageButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.arrow = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy, arrow;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? Semantics(
            label: 'Working',
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MirageColors.ink,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(label, textAlign: TextAlign.center)),
              if (arrow) ...[
                const SizedBox(width: 10),
                const MirageAsset(
                  'login_imgArrowRight.svg',
                  width: 19,
                  height: 19,
                ),
              ],
            ],
          ),
  );
}

class MirageField extends StatefulWidget {
  const MirageField({
    super.key,
    required this.label,
    required this.controller,
    this.password = false,
    this.hint,
    this.validator,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.enabled = true,
  });
  final String label;
  final TextEditingController controller;
  final bool password, enabled;
  final String? hint;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  @override
  State<MirageField> createState() => _MirageFieldState();
}

class _MirageFieldState extends State<MirageField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: Theme.of(context).textTheme.labelSmall),
      const SizedBox(height: 7),
      Semantics(
        label: widget.label,
        child: TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          obscureText: widget.password && !_visible,
          autocorrect:
              !widget.password &&
              widget.keyboardType != TextInputType.emailAddress,
          enableSuggestions: !widget.password,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hint,
            suffixIcon: widget.password
                ? IconButton(
                    onPressed: widget.enabled
                        ? () => setState(() => _visible = !_visible)
                        : null,
                    tooltip: _visible ? 'Hide password' : 'Show password',
                    icon: _visible
                        ? const Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: MirageColors.muted,
                          )
                        : const MirageAsset(
                            'login_imgEyeOff.svg',
                            width: 18,
                            height: 18,
                          ),
                  )
                : widget.keyboardType == TextInputType.emailAddress
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: MirageAsset(
                      'login_imgMail.svg',
                      width: 18,
                      height: 18,
                    ),
                  )
                : null,
          ),
        ),
      ),
    ],
  );
}

class MirageNotice extends StatelessWidget {
  const MirageNotice(
    this.message, {
    super.key,
    this.error = false,
    this.color,
    this.leading,
  });
  final String message;
  final Color? color;
  final Widget? leading;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFCE3EC) : color ?? MirageColors.blue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: error ? const Color(0xFF8B1946) : MirageColors.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
