import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:choke/l10n/generated/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../../services/nostr/nostr_service.dart';
import 'models/match.dart';
import 'providers/match_providers.dart';
import 'providers/match_control_provider.dart';
import '../home/providers/home_providers.dart';
import 'match_control_screen.dart';
import '../../shared/providers/match_duration_provider.dart';

// Fighter color palette sourced from BJJColors.fighterPalette

/// Convert Color to hex string (#RRGGBB)
String _colorToHex(Color color) {
  return '#${color.red.toRadixString(16).padLeft(2, '0')}'
          '${color.green.toRadixString(16).padLeft(2, '0')}'
          '${color.blue.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Format seconds as mm:ss — delegates to shared [formatDuration].
String _formatDuration(int seconds) => formatDuration(seconds);

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _f1NameController = TextEditingController();
  final _f2NameController = TextEditingController();

  Color _f1Color = BJJColors.fighterPalette[0]; // Green
  Color _f2Color = BJJColors.fighterPalette[1]; // Gold
  late int _duration;
  bool _isPublishing = false;
  bool _durationInitialized = false;

  @override
  void dispose() {
    _f1NameController.dispose();
    _f2NameController.dispose();
    super.dispose();
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPublishing = true);

    try {
      // Create match with auto-generated ID
      final match = Match.create(
        f1Name: _f1NameController.text.trim(),
        f2Name: _f2NameController.text.trim(),
        f1Color: _colorToHex(_f1Color),
        f2Color: _colorToHex(_f2Color),
        duration: _duration,
        status: MatchStatus.waiting,
        startAt: 0,
      );

      // Calculate expiration: now + 1 week
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiration = now + 604800; // 7 days

      // Publish to Nostr
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.publishAddressableEvent(
        dTag: match.id,
        content: match.toJsonString(),
        additionalTags: [
          ['expiration', expiration.toString()],
        ],
      );

      // Add to local state + home feed
      ref.read(matchListProvider.notifier).addMatch(match);
      ref.read(matchFeedProvider.notifier).addLocal(match);

      if (mounted) {
        // Set active match and navigate to control screen
        ref.read(activeMatchProvider.notifier).state = match;
        // Invalidate to force re-creation with new match
        ref.invalidate(matchControlProvider);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchControlScreen(match: match),
          ),
        );
      }
    } catch (e) {
      debugPrint('CreateMatch: publish failed: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.couldNotPublishMatch),
            backgroundColor: BJJColors.error,
            action: SnackBarAction(
              label: l10n.retry,
              textColor: BJJColors.white,
              onPressed: _createMatch,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initialize duration from provider only once
    if (!_durationInitialized) {
      _duration = ref.read(matchDurationProvider);
      _durationInitialized = true;
    }
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: BJJColors.navy,
      appBar: AppBar(
        title: Text(l10n.newMatch),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fighter 1
                _buildSectionLabel(l10n.fighter1),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _f1NameController,
                  style: const TextStyle(color: BJJColors.white),
                  decoration: InputDecoration(
                    hintText: l10n.enterFighterName,
                    prefixIcon:
                        const Icon(Icons.person, color: BJJColors.green),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.fighter1NameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildColorPicker(
                  label: l10n.fighter1Color,
                  selectedColor: _f1Color,
                  onColorSelected: (color) => setState(() => _f1Color = color),
                ),

                const SizedBox(height: 32),

                // Fighter 2
                _buildSectionLabel(l10n.fighter2),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _f2NameController,
                  style: const TextStyle(color: BJJColors.white),
                  decoration: InputDecoration(
                    hintText: l10n.enterFighterName,
                    prefixIcon: const Icon(Icons.person, color: BJJColors.gold),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.fighter2NameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildColorPicker(
                  label: l10n.fighter2Color,
                  selectedColor: _f2Color,
                  onColorSelected: (color) => setState(() => _f2Color = color),
                ),

                const SizedBox(height: 32),

                // Duration
                _buildSectionLabel(l10n.matchDuration),
                const SizedBox(height: 12),
                _buildDurationSelector(),

                const SizedBox(height: 48),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isPublishing ? null : _createMatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BJJColors.green,
                      foregroundColor: BJJColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor:
                          BJJColors.green.withValues(alpha: 0.5),
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BJJColors.white,
                            ),
                          )
                        : Text(
                            l10n.createMatch,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: BJJColors.grey,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildColorPicker({
    required String label,
    required Color selectedColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BJJColors.grey.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: BJJColors.fighterPalette.map((color) {
            final isSelected = color == selectedColor;
            return GestureDetector(
              onTap: () => onColorSelected(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? BJJColors.white
                        : BJJColors.greyDark.withValues(alpha: 0.5),
                    width: isSelected ? 3 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color == BJJColors.white
                            ? BJJColors.navy
                            : BJJColors.white,
                        size: 18,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: defaultDurationOptions.map((seconds) {
        final isSelected = seconds == _duration;
        return GestureDetector(
          onTap: () => setState(() => _duration = seconds),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? BJJColors.green : BJJColors.navyDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? BJJColors.green
                    : BJJColors.greyDark.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              _formatDuration(seconds),
              style: TextStyle(
                color: isSelected ? BJJColors.white : BJJColors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
