import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'live_osm_map_widget.dart';

class MapExportModal extends StatelessWidget {
  const MapExportModal(
      {super.key,
      required this.location,
      required this.currentAddress,
      this.destination,
      this.routePoints = const []});
  final Geo location;
  final String currentAddress;
  final Place? destination;
  final List<Geo> routePoints;
  Uri get mapUrl => Uri.parse(
      'https://www.openstreetmap.org/?mlat=${location.lat}&mlon=${location.lng}#map=16/${location.lat}/${location.lng}');

  @override
  Widget build(BuildContext context) => SafeArea(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Share Map Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
            ]),
            SizedBox(
                height: 180,
                child: LiveOsmMapWidget(
                    passengerLocation: location,
                    currentAddress: currentAddress,
                    destination: destination,
                    routePoints: routePoints)),
            const SizedBox(height: 12),
            Text(currentAddress),
            const SizedBox(height: 8),
            const Text('This link shares your current map location.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Map Link'),
                onPressed: () async {
                  try {
                    await Clipboard.setData(
                        ClipboardData(text: mapUrl.toString()));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Map link copied.')));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Unable to copy the map link.')));
                    }
                  }
                }),
            TextButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in OpenStreetMap'),
                onPressed: () async {
                  try {
                    if (await launchUrl(mapUrl,
                        mode: LaunchMode.externalApplication)) {
                      return;
                    }
                  } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Unable to open the map.')));
                  }
                }),
          ],
        ),
      ));
}
