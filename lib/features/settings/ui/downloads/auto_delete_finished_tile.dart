import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:storii/app/init.dart';
import 'package:storii/app/models/enums.dart';
import 'package:storii/app/providers/settings_provider.dart';
import 'package:storii/shared/widgets/app_bottom_sheet.dart';
import 'package:storii/shared/widgets/app_buttons.dart';
import 'package:storii/shared/widgets/wheel_picker.dart';

class AutoDeleteFinishedTile extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(autoDeleteFinishedDownloadsProvider);
    final delay = ref.watch(autoDeleteFinishedDelayProvider);

    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          trailing: const Icon(Icons.chevron_right),
          title: Text(l10n.autoDeleteFinishedDownloads),
          subtitle: Text(
            mode == .afterDelay
                ? '${mode.label} · ${_delayLabel(delay)}'
                : mode.label,
          ),
          onTap: () {
            AppBottomSheet.show(
              context,
              title: l10n.autoDeleteFinishedDownloads,
              subtitle: l10n.autoDeleteFinishedDownloadsSubtitle,
              body: Consumer(
                builder: (context, ref, _) {
                  final mode = ref.watch(autoDeleteFinishedDownloadsProvider);
                  return RadioGroup<AutoDeleteFinishedDownloads>(
                    groupValue: mode,
                    onChanged: (target) {
                      if (target == null) return;
                      ref
                          .read(userSettingsProvider.notifier)
                          .setAutoDeleteFinishedDownloads(target);
                    },
                    child: Column(
                      children: [
                        ...AutoDeleteFinishedDownloads.values.map(
                          (m) => RadioListTile(value: m, title: Text(m.label)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        if (mode == .afterDelay)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(l10n.autoDeleteDelay),
            trailing: Text(_delayLabel(delay)),
            onTap: () => _pickDelay(context, ref, delay),
          ),
      ],
    );
  }

  void _pickDelay(BuildContext context, WidgetRef ref, Duration current) {
    var hours = current.inHours.clamp(1, 168);

    AppBottomSheet.show(
      context,
      title: l10n.autoDeleteDelay,
      subtitle: l10n.autoDeleteDelayDescription,
      body: Builder(
        builder: (context) {
          return Padding(
            padding: const .symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                WheelPicker.fromIntRange(
                  initialValue: hours,
                  min: 1,
                  max: 168,
                  step: 1,
                  presets: const [1, 6, 12, 24, 48, 72, 168],
                  labelBuilder: l10n.timeHours,
                  onChangedEnd: (v) => hours = v,
                ),
                const SizedBox(height: 24),
                AppFilledButton(
                  onPressed: () {
                    ref
                        .read(userSettingsProvider.notifier)
                        .setAutoDeleteFinishedDelay(Duration(hours: hours));
                    Navigator.of(context).pop();
                  },
                  text: l10n.save,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _delayLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0 && minutes == 0) return l10n.timeHours(hours);
  if (hours == 0) return l10n.timeMinutes(minutes);
  return '${l10n.timeHours(hours)} ${l10n.timeMinutes(minutes)}';
}
