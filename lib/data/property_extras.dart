/// Columns that carry the richer property details. Shared by the student view,
/// the landlord view and the add-property flow.
const kExtrasColumns = 'school_other,landmark,bedrooms,bathrooms,bathroom_type,kitchen_type,furnishing,gender_preference,'
    'max_occupants,available_from,lease_months,allows_instalments,caution_fee_ngn,service_charge_ngn,'
    'landlord_lives_on_site,visitors_allowed,pets_allowed,house_rules,walk_minutes,bike_fare_ngn,keke_fare_ngn,bus_fare_ngn,electricity_billing,water_billing';

const furnishingLabels = {'unfurnished': 'Unfurnished', 'semi_furnished': 'Semi-furnished', 'furnished': 'Furnished'};
const genderLabels = {'any': 'Anyone', 'male_only': 'Male students only', 'female_only': 'Female students only'};
const bathroomLabels = {'private': 'Private bathroom', 'shared': 'Shared bathroom'};
const electricityLabels = {'prepaid': 'Prepaid meter (you buy units)', 'shared': 'Shared bill', 'included': 'Included in the rent'};
const waterLabels = {'included': 'Included in the rent', 'separate': 'You pay separately'};
const kitchenLabels = {'private': 'Private kitchen', 'shared': 'Shared kitchen', 'none': 'No kitchen'};

class PropertyExtras {
  final String schoolOther, landmark, bathroomType, kitchenType, furnishing, genderPreference, houseRules;
  final int bedrooms, bathrooms, maxOccupants;
  final int? leaseMonths, cautionFeeNgn, serviceChargeNgn, walkMinutes, bikeFareNgn, kekeFareNgn, busFareNgn;
  final String? electricityBilling, waterBilling;
  final DateTime? availableFrom;
  final bool allowsInstalments, landlordLivesOnSite, visitorsAllowed, petsAllowed;

  const PropertyExtras({
    this.schoolOther = '',
    this.landmark = '',
    this.bedrooms = 1,
    this.bathrooms = 1,
    this.bathroomType = 'private',
    this.kitchenType = 'shared',
    this.furnishing = 'unfurnished',
    this.genderPreference = 'any',
    this.maxOccupants = 1,
    this.availableFrom,
    this.leaseMonths,
    this.allowsInstalments = false,
    this.cautionFeeNgn,
    this.serviceChargeNgn,
    this.landlordLivesOnSite = false,
    this.visitorsAllowed = true,
    this.petsAllowed = false,
    this.houseRules = '',
    this.walkMinutes,
    this.bikeFareNgn,
    this.kekeFareNgn,
    this.busFareNgn,
    this.electricityBilling,
    this.waterBilling,
  });

  factory PropertyExtras.fromMap(Map<String, dynamic> m) => PropertyExtras(
        schoolOther: (m['school_other'] ?? '') as String,
        landmark: (m['landmark'] ?? '') as String,
        bedrooms: (m['bedrooms'] as num?)?.toInt() ?? 1,
        bathrooms: (m['bathrooms'] as num?)?.toInt() ?? 1,
        bathroomType: (m['bathroom_type'] ?? 'private') as String,
        kitchenType: (m['kitchen_type'] ?? 'shared') as String,
        furnishing: (m['furnishing'] ?? 'unfurnished') as String,
        genderPreference: (m['gender_preference'] ?? 'any') as String,
        maxOccupants: (m['max_occupants'] as num?)?.toInt() ?? 1,
        availableFrom: m['available_from'] == null ? null : DateTime.tryParse(m['available_from'] as String),
        leaseMonths: (m['lease_months'] as num?)?.toInt(),
        allowsInstalments: (m['allows_instalments'] ?? false) as bool,
        cautionFeeNgn: (m['caution_fee_ngn'] as num?)?.toInt(),
        serviceChargeNgn: (m['service_charge_ngn'] as num?)?.toInt(),
        landlordLivesOnSite: (m['landlord_lives_on_site'] ?? false) as bool,
        visitorsAllowed: (m['visitors_allowed'] ?? true) as bool,
        petsAllowed: (m['pets_allowed'] ?? false) as bool,
        houseRules: (m['house_rules'] ?? '') as String,
        walkMinutes: (m['walk_minutes'] as num?)?.toInt(),
        bikeFareNgn: (m['bike_fare_ngn'] as num?)?.toInt(),
        kekeFareNgn: (m['keke_fare_ngn'] as num?)?.toInt(),
        busFareNgn: (m['bus_fare_ngn'] as num?)?.toInt(),
        electricityBilling: m['electricity_billing'] as String?,
        waterBilling: m['water_billing'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'school_other': schoolOther.isEmpty ? null : schoolOther,
        'landmark': landmark.isEmpty ? null : landmark,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'bathroom_type': bathroomType,
        'kitchen_type': kitchenType,
        'furnishing': furnishing,
        'gender_preference': genderPreference,
        'max_occupants': maxOccupants,
        'available_from': availableFrom == null ? null : availableFrom!.toIso8601String().substring(0, 10),
        'lease_months': leaseMonths,
        'allows_instalments': allowsInstalments,
        'caution_fee_ngn': cautionFeeNgn,
        'service_charge_ngn': serviceChargeNgn,
        'landlord_lives_on_site': landlordLivesOnSite,
        'visitors_allowed': visitorsAllowed,
        'pets_allowed': petsAllowed,
        'house_rules': houseRules.isEmpty ? null : houseRules,
        'walk_minutes': walkMinutes,
        'bike_fare_ngn': bikeFareNgn,
        'keke_fare_ngn': kekeFareNgn,
        'bus_fare_ngn': busFareNgn,
        'electricity_billing': electricityBilling,
        'water_billing': waterBilling,
      };
}
