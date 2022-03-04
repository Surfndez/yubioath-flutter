import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:yubico_authenticator/app/state.dart';

import '../../app/models.dart';
import '../models.dart';
import '../state.dart';

final _mapEquals = const DeepCollectionEquality().equals;

class _CapabilityForm extends StatelessWidget {
  final int capabilities;
  final int enabled;
  final Function(int) onChanged;
  const _CapabilityForm(
      {required this.capabilities,
      required this.enabled,
      required this.onChanged,
      Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.0,
      runSpacing: 6.0,
      children: Capability.values
          .where((c) => capabilities & c.value != 0)
          .map((c) => FilterChip(
                showCheckmark: true,
                selected: enabled & c.value != 0,
                label: Text(c.name),
                onSelected: (_) {
                  onChanged(enabled ^ c.value);
                },
              ))
          .toList(),
    );
  }
}

class _CapabilitiesForm extends StatefulWidget {
  final DeviceInfo info;
  final Function(Map<Transport, int>) onSubmit;

  const _CapabilitiesForm(this.info, {required this.onSubmit, Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _CapabilitiesFormState();
}

class _CapabilitiesFormState extends State<_CapabilitiesForm> {
  late Map<Transport, int> _enabled;

  @override
  void initState() {
    super.initState();
    // Make sure to copy enabledCapabilites, not mutate the original.
    _enabled = {...widget.info.config.enabledCapabilities};
  }

  @override
  Widget build(BuildContext context) {
    final usbCapabilities =
        widget.info.supportedCapabilities[Transport.usb] ?? 0;
    final nfcCapabilities =
        widget.info.supportedCapabilities[Transport.nfc] ?? 0;

    final changed =
        !_mapEquals(widget.info.config.enabledCapabilities, _enabled);
    final valid = changed && (_enabled[Transport.usb] ?? 0) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (usbCapabilities != 0)
          const ListTile(
            leading: Icon(Icons.usb),
            title: Text('USB applications'),
          ),
        _CapabilityForm(
          capabilities: usbCapabilities,
          enabled: _enabled[Transport.usb] ?? 0,
          onChanged: (enabled) {
            setState(() {
              _enabled[Transport.usb] = enabled;
            });
          },
        ),
        if (nfcCapabilities != 0)
          const ListTile(
            leading: Icon(Icons.wifi),
            title: Text('NFC applications'),
          ),
        _CapabilityForm(
          capabilities: nfcCapabilities,
          enabled: _enabled[Transport.nfc] ?? 0,
          onChanged: (enabled) {
            setState(() {
              _enabled[Transport.nfc] = enabled;
            });
          },
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: valid
                ? () {
                    widget.onSubmit(_enabled);
                  }
                : null,
            child: const Text('Apply changes'),
          ),
        )
      ],
    );
  }
}

class ManagementScreen extends ConsumerWidget {
  final YubiKeyData deviceData;
  const ManagementScreen(this.deviceData, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(managementStateProvider(deviceData.node.path));

    if (state == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return ListView(
      children: [
        _CapabilitiesForm(state, onSubmit: (enabled) async {
          final bool reboot;
          if (deviceData.node is UsbYubiKeyNode) {
            final oldInterfaces = UsbInterfaces.forCapabilites(
                state.config.enabledCapabilities[Transport.usb] ?? 0);
            final newInterfaces =
                UsbInterfaces.forCapabilites(enabled[Transport.usb] ?? 0);
            reboot = oldInterfaces != newInterfaces;
          } else {
            reboot = false;
          }

          Function()? close;
          try {
            if (reboot) {
              close = ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(
                    content: Text('Reconfiguring YubiKey...'),
                    duration: Duration(seconds: 8),
                  ))
                  .close;
            }
            final config = state.config.copyWith(enabledCapabilities: enabled);
            await ref
                .read(managementStateProvider(deviceData.node.path).notifier)
                .writeConfig(
                  config,
                  reboot: reboot,
                );
            if (!reboot) {
              ref
                  .read(currentDeviceDataProvider.notifier)
                  .updateDeviceConfig(config);
            }
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Configuration updated'),
              duration: Duration(seconds: 2),
            ));
          } finally {
            close?.call();
          }
        })
      ],
    );
  }
}
