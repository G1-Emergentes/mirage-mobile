import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../shared/network/api_client.dart';
import '../../../shared/widgets/mirage_components.dart';
import '../../../shared/widgets/mirage_feature_components.dart';
import '../../infrastructure/dio_profile_repository.dart';
import 'measurement_model_screen.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    super.key,
    required this.section,
    required this.profile,
    required this.save,
  });

  final ProfileSection section;
  final Map<String, dynamic> profile;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) save;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  static const _identity = {
    'displayName': 'Display name',
    'profileImageUrl': 'Profile photo URL',
  };
  static const _measurements = {
    'height': 'Height',
    'shoulderWidth': 'Shoulder width',
    'chest': 'Chest',
    'waist': 'Waist',
    'hip': 'Hips',
  };
  static const _preferences = {
    'preferredStyles': 'Preferred styles',
    'preferredColors': 'Preferred colors',
    'avoidedColors': 'Colors to avoid',
    'preferredCategories': 'Preferred categories',
  };

  final _form = GlobalKey<FormState>();
  late final _fields = switch (widget.section) {
    ProfileSection.identity => _identity,
    ProfileSection.measurements => _measurements,
    ProfileSection.preferences => _preferences,
  };
  late final _inputs = {
    for (final key in _fields.keys)
      key: TextEditingController(text: _initial(key)),
  };
  bool _saving = false;
  String? _error;

  String _initial(String key) {
    final source = widget.section == ProfileSection.identity
        ? widget.profile
        : widget.profile[widget.section.name];
    final value = source is Map ? source[key] : null;
    return value is List ? value.join('\n') : value?.toString() ?? '';
  }

  List<String> _entries(String value) => value
      .split('\n')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  String? _validate(String key, String text) {
    final value = text.trim();
    switch (widget.section) {
      case ProfileSection.identity:
        if (key == 'displayName') {
          if (value.isEmpty || utf8.encode(value).length > 100) {
            return 'Enter a name of up to 100 bytes.';
          }
        } else if (value.isNotEmpty) {
          final uri = Uri.tryParse(value);
          if (uri == null ||
              uri.scheme != 'https' ||
              uri.host.isEmpty ||
              utf8.encode(value).length > 2048 ||
              RegExp(r'\s').hasMatch(value)) {
            return 'Enter a valid HTTPS image URL.';
          }
        }
      case ProfileSection.measurements:
        final number = _number(value);
        if (number == null ||
            !number.isFinite ||
            number <= 0 ||
            number > 1000) {
          return 'Enter a value greater than 0 and up to 1000 cm.';
        }
      case ProfileSection.preferences:
        final entries = _entries(value);
        if (entries.length > 50 ||
            entries.any((entry) => utf8.encode(entry).length > 80) ||
            entries.toSet().length != entries.length) {
          return 'Use up to 50 unique entries of 80 bytes each.';
        }
        if (key == 'avoidedColors' &&
            _entries(
              _inputs['preferredColors']!.text,
            ).toSet().intersection(entries.toSet()).isNotEmpty) {
          return 'A preferred color cannot also be avoided.';
        }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        if (widget.section == ProfileSection.identity)
          'birthDate': widget.profile['birthDate'],
        for (final entry in _inputs.entries)
          entry.key: switch (widget.section) {
            ProfileSection.identity =>
              entry.value.text.trim().isEmpty ? null : entry.value.text.trim(),
            ProfileSection.measurements => _number(entry.value.text),
            ProfileSection.preferences => _entries(entry.value.text),
          },
      };
      final result = await widget.save(data);
      if (mounted) Navigator.pop(context, result);
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() => _error = 'Could not save profile (${failure.code}).');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save profile. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _generateModel() {
    if (_saving || !_form.currentState!.validate()) return;
    final measurements = {
      for (final entry in _inputs.entries)
        entry.key: _number(entry.value.text)!,
    };
    for (final entry in measurementModelLimits.entries) {
      final (min, max) = entry.value;
      final value = measurements[entry.key]!;
      if (value < min || value > max) {
        setState(
          () => _error =
              '${_fields[entry.key]}: el modelo admite de $min a $max cm.',
        );
        return;
      }
    }
    setState(() => _error = null);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MeasurementModelScreen(measurements: measurements),
      ),
    );
  }

  @override
  void dispose() {
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (widget.section) {
      ProfileSection.identity => (
        'Edit Profile',
        'Leave the photo URL empty to use the default image.',
      ),
      ProfileSection.measurements => (
        'Measurements',
        'Enter all five measurements in centimeters.',
      ),
      ProfileSection.preferences => (
        'Preferences',
        'Enter one value per line.',
      ),
    };
    return PopScope(
      canPop: !_saving,
      child: MirageFeaturePage(
        title: title,
        subtitle: subtitle,
        onBack: _saving ? null : () => Navigator.pop(context),
        children: [
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final field in _fields.entries) ...[
                  Text(
                    field.value,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _inputs[field.key],
                    enabled: !_saving,
                    maxLines: widget.section == ProfileSection.preferences
                        ? 3
                        : 1,
                    keyboardType: widget.section == ProfileSection.measurements
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : field.key == 'profileImageUrl'
                        ? TextInputType.url
                        : null,
                    validator: (value) => _validate(field.key, value ?? ''),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_error != null) MirageNotice(_error!, error: true),
                MirageButton(
                  label: 'Save Changes',
                  busy: _saving,
                  onPressed: _save,
                ),
                if (widget.section == ProfileSection.measurements) ...[
                  const SizedBox(height: 10),
                  MirageButton(
                    label: 'Generar modelo 3D',
                    onPressed: _saving ? null : _generateModel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
