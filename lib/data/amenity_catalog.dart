import 'package:flutter/material.dart';

class Amenity {
  final int id;
  final String code, label, category;
  final IconData icon;
  const Amenity(this.id, this.code, this.label, this.category, this.icon);
}

/// Must match the cs_amenities rows seeded by migration 0006.
const amenityCatalog = <Amenity>[
  Amenity(2, 'water', 'Water', 'utilities', Icons.water_drop_outlined),
  Amenity(9, 'borehole', 'Borehole water', 'utilities', Icons.opacity),
  Amenity(3, 'electricity', 'Electricity', 'utilities', Icons.bolt),
  Amenity(10, 'prepaid_meter', 'Prepaid meter', 'utilities', Icons.speed),
  Amenity(11, 'generator', 'Generator or inverter', 'utilities', Icons.power),
  Amenity(12, 'solar', 'Solar power', 'utilities', Icons.wb_sunny_outlined),
  Amenity(1, 'wifi', 'WiFi', 'comfort', Icons.wifi),
  Amenity(8, 'ac', 'Air conditioning', 'comfort', Icons.ac_unit),
  Amenity(13, 'fan', 'Ceiling fan', 'comfort', Icons.toys_outlined),
  Amenity(14, 'wardrobe', 'Wardrobe', 'comfort', Icons.checkroom_outlined),
  Amenity(15, 'bed', 'Bed and mattress', 'comfort', Icons.bed_outlined),
  Amenity(16, 'fridge', 'Fridge', 'comfort', Icons.kitchen_outlined),
  Amenity(17, 'tv', 'TV or DStv', 'comfort', Icons.tv),
  Amenity(18, 'gas_cooker', 'Gas cooker', 'comfort', Icons.local_fire_department_outlined),
  Amenity(28, 'water_heater', 'Water heater', 'comfort', Icons.hot_tub_outlined),
  Amenity(19, 'tiled', 'Tiled floors', 'comfort', Icons.grid_view),
  Amenity(20, 'pop_ceiling', 'POP ceiling', 'comfort', Icons.roofing),
  Amenity(5, 'cctv', 'CCTV', 'security', Icons.videocam_outlined),
  Amenity(21, 'security_guard', 'Security guard', 'security', Icons.local_police_outlined),
  Amenity(22, 'gated', 'Gated compound', 'security', Icons.fence),
  Amenity(23, 'fenced', 'Fenced', 'security', Icons.border_outer),
  Amenity(24, 'burglar_proof', 'Burglar-proof doors and windows', 'security', Icons.lock_outline),
  Amenity(4, 'parking', 'Parking', 'convenience', Icons.local_parking),
  Amenity(6, 'kitchen', 'Kitchen', 'convenience', Icons.soup_kitchen_outlined),
  Amenity(7, 'laundry', 'Laundry', 'convenience', Icons.local_laundry_service_outlined),
  Amenity(25, 'study_area', 'Study area', 'convenience', Icons.menu_book_outlined),
  Amenity(26, 'balcony', 'Balcony', 'convenience', Icons.balcony),
  Amenity(27, 'cleaning', 'Cleaning service', 'convenience', Icons.cleaning_services_outlined),
  Amenity(29, 'tarred_road', 'Tarred road access', 'convenience', Icons.add_road),
  Amenity(30, 'near_transport', 'Close to transport', 'convenience', Icons.directions_bus_outlined),
  Amenity(31, 'near_shops', 'Close to shops', 'convenience', Icons.storefront_outlined),
];

const amenityCategoryLabels = {
  'utilities': 'Water and power',
  'comfort': 'Comfort and furnishing',
  'security': 'Security',
  'convenience': 'Convenience and location',
};

final Map<String, String> amenityLabels = {for (final a in amenityCatalog) a.code: a.label};
final Map<String, int> amenityIds = {for (final a in amenityCatalog) a.code: a.id};
final Map<String, IconData> amenityIcons = {for (final a in amenityCatalog) a.code: a.icon};
