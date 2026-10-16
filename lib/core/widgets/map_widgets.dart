import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../errors.dart';
import '../location_service.dart';
import '../theme/tokens.dart';
import 'error_views.dart';

/// Roughly the middle of Nigeria, used when there is nothing better to show.
const nigeriaCenter = LatLng(9.0820, 8.6753);

TileLayer csTileLayer() => TileLayer(urlTemplate: AppConfig.mapTileUrl, userAgentPackageName: 'com.campusstay.campusstay', maxNativeZoom: 19);

Widget csAttribution() => RichAttributionWidget(attributions: [TextSourceAttribution(AppConfig.mapAttribution)]);

/// Shows one listing: a soft circle for the approximate area, or a pin once the exact spot is unlocked.
class ListingMap extends StatelessWidget {
  final LatLng center;
  final bool exact;
  final double height;
  const ListingMap({super.key, required this.center, required this.exact, this.height = 220});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CS.rMd),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: exact ? 16 : 14,
              minZoom: 5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              csTileLayer(),
              if (exact)
                MarkerLayer(markers: [
                  Marker(point: center, width: 44, height: 44, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: CS.danger, size: 44)),
                ])
              else
                CircleLayer(circles: [
                  CircleMarker(point: center, radius: 450, useRadiusInMeter: true, color: CS.green.withValues(alpha: 0.2), borderColor: CS.green, borderStrokeWidth: 2),
                ]),
              csAttribution(),
            ],
          ),
        ),
      );
}

/// Landlord picks the spot by moving the map under a fixed crosshair, then taps "Set pin here".
class LocationPicker extends StatefulWidget {
  final LatLng? initial;
  final ValueChanged<LatLng?> onChanged;
  const LocationPicker({super.key, required this.initial, required this.onChanged});
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _mc = MapController();
  late LatLng _center = widget.initial ?? nigeriaCenter;
  late LatLng? _pin = widget.initial;
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final p = await DeviceLocation.current();
      final here = LatLng(p.lat, p.lng);
      _mc.move(here, 17);
      setState(() => _center = here);
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _useMyLocation);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setPin() {
    // The database only accepts Nigerian coordinates, so say so before sending.
    if (_center.latitude < 3.5 || _center.latitude > 14.0 || _center.longitude < 2.0 || _center.longitude > 15.5) {
      showError(context, const AppException(AppErrorKind.invalid, detail: 'That spot is outside Nigeria. Move the map to the property.'));
      return;
    }
    setState(() => _pin = _center);
    widget.onChanged(_pin);
  }

  void _clear() {
    setState(() => _pin = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CS.rMd),
            child: Stack(children: [
              FlutterMap(
                mapController: _mc,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: widget.initial != null ? 17 : 6,
                  minZoom: 5,
                  maxZoom: 19,
                  onPositionChanged: (camera, hasGesture) => _center = camera.center,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  csTileLayer(),
                  if (_pin != null)
                    MarkerLayer(markers: [Marker(point: _pin!, width: 40, height: 40, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: CS.green, size: 40))]),
                  csAttribution(),
                ],
              ),
              const IgnorePointer(child: Center(child: Icon(Icons.add, size: 34, color: CS.danger))),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _locating ? null : _useMyLocation, icon: _locating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location), label: const Text('Use my location'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(onPressed: _setPin, icon: const Icon(Icons.push_pin_outlined), label: const Text('Set pin here'))),
        ]),
        if (_pin != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.check_circle, color: CS.green, size: 18),
              const SizedBox(width: 6),
              const Expanded(child: Text('Pin saved', style: TextStyle(color: CS.green, fontWeight: FontWeight.w700))),
              TextButton(onPressed: _clear, child: const Text('Remove pin')),
            ]),
          ),
      ]);
}
