import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/location_service.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/error_views.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/location_models.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../property/property_detail_screen.dart';

/// Listings as pins. Pins show approximate areas, never the exact address.
class MapExploreScreen extends StatefulWidget {
  final SearchFilter filter;
  const MapExploreScreen({super.key, required this.filter});
  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  final _mc = MapController();
  List<Property> _items = [];
  Property? _selected;
  bool _loading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _mc.dispose();
    super.dispose();
  }

  Future<void> _fetch({required double south, required double west, required double north, required double east, bool fit = false}) async {
    setState(() => _loading = true);
    try {
      final r = await Services.repo.mapListings(widget.filter, south: south, west: west, north: north, east: east);
      if (!mounted) return;
      setState(() {
        _items = r;
        if (_selected != null && !r.any((p) => p.id == _selected!.id)) _selected = null;
      });
      if (fit && r.isNotEmpty) {
        final pts = [for (final p in r) LatLng(p.approxLat!, p.approxLng!)];
        if (pts.length == 1) {
          _mc.move(pts.first, 14);
        } else {
          _mc.fitCamera(CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(70), maxZoom: 15));
        }
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initial() => _fetch(south: 3.5, west: 2.0, north: 14.0, east: 15.5, fit: true);

  void _moved(MapCamera cam, bool gesture) {
    if (!gesture) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final b = cam.visibleBounds;
      _fetch(south: b.south, west: b.west, north: b.north, east: b.east);
    });
  }

  Future<void> _myLocation() async {
    try {
      final p = await DeviceLocation.current();
      _mc.move(LatLng(p.lat, p.lng), 14);
    } catch (e) {
      if (mounted) showError(context, e, onRetry: _myLocation);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Map')),
        body: Stack(children: [
          FlutterMap(
            mapController: _mc,
            options: MapOptions(
              initialCenter: nigeriaCenter,
              initialZoom: 6,
              minZoom: 5,
              maxZoom: 19,
              onMapReady: _initial,
              onPositionChanged: _moved,
              onTap: (_, __) => setState(() => _selected = null),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              csTileLayer(),
              MarkerLayer(markers: [
                for (final p in _items)
                  if (p.approxLat != null && p.approxLng != null)
                    Marker(
                      point: LatLng(p.approxLat!, p.approxLng!),
                      width: 84,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = p),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selected?.id == p.id ? CS.navy : CS.blue,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: CS.shadow,
                          ),
                          child: Text(compactNaira(p.rentNgn), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ),
              ]),
              csAttribution(),
            ],
          ),
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(CS.rMd), boxShadow: CS.shadow),
              child: Row(children: [
                if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) else const Icon(Icons.info_outline, size: 16, color: CS.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(_loading ? 'Loading listings…' : '${_items.length} listing${_items.length == 1 ? '' : 's'} here. Pins show approximate areas.', style: const TextStyle(fontSize: 12.5))),
              ]),
            ),
          ),
          Positioned(
            right: 12,
            bottom: _selected == null ? 16 : 150,
            child: FloatingActionButton.small(heroTag: 'mylocation', tooltip: 'My location', onPressed: _myLocation, child: const Icon(Icons.my_location)),
          ),
          if (_selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(CS.rLg),
                color: CS.bg,
                child: Padding(
                  padding: const EdgeInsets.all(CS.s16),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selected!.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(_selected!.locationLabel, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(_selected!.rentLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CS.blue)),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: _selected!.id))),
                        child: const Text('View listing'),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
        ]),
      );
}
