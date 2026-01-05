import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/guest_booking_storage.dart';
import '../../providers/auth_provider.dart';
import '../booking/booking_detail_screen.dart';

const String API_BASE_URL = 'https://megatour.vn/api/';

// --- Configuration Models ---

class ServiceConfig {
  final String label;
  final IconData icon;
  final IconData fallbackIcon;

  const ServiceConfig({
    required this.label,
    required this.icon,
    required this.fallbackIcon,
  });
}

class AppCurrency {
  final String symbol;
  final String format; // 'left' or 'right'
  final String thousand;
  final String decimal;
  final int precision;

  AppCurrency({
    required this.symbol,
    required this.format,
    required this.thousand,
    required this.decimal,
    required this.precision,
  });

  factory AppCurrency.fromJson(Map<String, dynamic> json) {
    return AppCurrency(
      symbol: json['symbol'] ?? '\$', // Fixed: Escaped the $
      format: json['currency_format'] ?? 'left',
      thousand: json['currency_thousand'] ?? '.',
      decimal: json['currency_decimal'] ?? ',',
      precision: int.tryParse('${json['currency_no_decimal']}') ?? 2,
    );
  }

  // Helper to format price string manually without external Intl library
  String formatPrice(String? priceStr) {
    double amount = double.tryParse('$priceStr') ?? 0.0;
    
    // 1. Handle Precision
    String value = amount.toStringAsFixed(precision);
    
    // 2. Split decimals
    List<String> parts = value.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    // 3. Add Thousand Separator
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String Function(Match) mathFunc = (Match match) => '${match[1]}$thousand';
    integerPart = integerPart.replaceAllMapped(reg, mathFunc);

    // 4. Join with Custom Decimal Separator
    String formattedNum = decimalPart.isNotEmpty 
        ? '$integerPart$decimal$decimalPart' 
        : integerPart;

    // 5. Add Symbol
    if (format == 'right') {
      return '$formattedNum$symbol';
    } else {
      return '$symbol$formattedNum';
    }
  }
}

const Map<String, ServiceConfig> kServiceConfig = {
  'hotel': ServiceConfig(
    label: 'Hotel',
    icon: Icons.hotel,
    fallbackIcon: Icons.apartment,
  ),
  'tour': ServiceConfig(
    label: 'Tour',
    icon: Icons.map,
    fallbackIcon: Icons.travel_explore,
  ),
  'car': ServiceConfig(
    label: 'Car',
    icon: Icons.directions_car,
    fallbackIcon: Icons.directions_car,
  ),
  'visa': ServiceConfig(
    label: 'Visa',
    icon: Icons.badge,
    fallbackIcon: Icons.assignment_ind,
  ),
  'flight': ServiceConfig(
    label: 'Flight',
    icon: Icons.flight,
    fallbackIcon: Icons.flight_takeoff,
  ),
  'space': ServiceConfig(
    label: 'Space',
    icon: Icons.meeting_room,
    fallbackIcon: Icons.domain,
  ),
  'event': ServiceConfig(
    label: 'Event',
    icon: Icons.event,
    fallbackIcon: Icons.event_available,
  ),
  'boat': ServiceConfig(
    label: 'Boat',
    icon: Icons.directions_boat,
    fallbackIcon: Icons.directions_boat,
  ),
};

// --- Main Widget ---

class BookingsTab extends StatefulWidget {
  const BookingsTab({Key? key}) : super(key: key);

  @override
  State<BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<BookingsTab> {
  late Future<List<BookingItem>> _future;
  AppCurrency? _appCurrency;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<List<BookingItem>> _loadData() async {
    // 1. Fetch Configs to get Currency
    try {
      final configRes = await http.get(Uri.parse('${API_BASE_URL}configs'));
      if (configRes.statusCode == 200) {
        final json = jsonDecode(configRes.body);
        final List currencies = json['currency'] ?? [];
        // Find main currency or default to first
        final mainCurrData = currencies.firstWhere(
            (element) => element['is_main'] == 1,
            orElse: () => currencies.isNotEmpty ? currencies.first : null);
        
        if (mainCurrData != null) {
          _appCurrency = AppCurrency.fromJson(mainCurrData);
        }
      }
    } catch (e) {
      debugPrint('Error loading configs: $e');
    }

    // 2. Fetch Bookings
    final auth = context.read<AuthProvider>();

    if (auth.isAuthenticated && auth.token != null) {
      final res = await http.get(
        Uri.parse('${API_BASE_URL}user/booking-history'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
      );
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      final List data = decoded['data'] ?? [];
      return data.map((e) => BookingItem.fromJson(e)).toList();
    }

    final local = await GuestBookingStorage.loadBookings();
    return local.map((e) => BookingItem.fromJson(e)).toList();
  }

  Map<String, List<BookingItem>> _groupByService(List<BookingItem> items) {
    final map = <String, List<BookingItem>>{};
    for (final i in items) {
      map.putIfAbsent(i.objectModel, () => []).add(i);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return const Center(child: Text('Login to view your bookings'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('My Bookings'),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<BookingItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No bookings yet'));
          }

          final now = DateTime.now();
          final upcoming = items.where((e) => e.endDate.isAfter(now)).toList();
          final past = items.where((e) => e.endDate.isBefore(now)).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 140),
            children: [
              if (upcoming.isNotEmpty)
                _SectionGroup(
                  title: 'Upcoming',
                  grouped: _groupByService(upcoming),
                  currency: _appCurrency,
                  onRefresh: () async {
                    setState(() => _future = _loadData());
                    await _future;
                  },
                ),
              if (past.isNotEmpty)
                _SectionGroup(
                  title: 'Past',
                  grouped: _groupByService(past),
                  currency: _appCurrency,
                  onRefresh: () async {
                    setState(() => _future = _loadData());
                    await _future;
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final String title;
  final Map<String, List<BookingItem>> grouped;
  final AppCurrency? currency;
  final Future<void> Function() onRefresh;

  const _SectionGroup({
    required this.title,
    required this.grouped,
    required this.currency,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...grouped.entries.map((e) {
          return _ServiceRow(
            serviceType: e.key,
            items: e.value,
            currency: currency,
            onRefresh: onRefresh,
          );
        }),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String serviceType;
  final List<BookingItem> items;
  final AppCurrency? currency;
  final Future<void> Function() onRefresh;

  const _ServiceRow({
    required this.serviceType,
    required this.items,
    this.currency,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final config = kServiceConfig[serviceType];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(config?.icon ?? Icons.travel_explore, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  config?.label ?? serviceType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _ViewAllScreen(
                        serviceType: serviceType, 
                        items: items,
                        currency: currency,
                      ),
                    ),
                  );
                },
                child: const Text('View all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                return _BookingCardLight(item: items[i], currency: currency);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingCardLight extends StatelessWidget {
  final BookingItem item;
  final AppCurrency? currency;

  const _BookingCardLight({required this.item, this.currency});

  @override
  Widget build(BuildContext context) {
    final config = kServiceConfig[item.objectModel];
    
    // Determine the price string to display
    String priceDisplay = item.totalFormatted;
    if (currency != null) {
      priceDisplay = currency!.formatPrice(item.total);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BookingDetailScreen(bookingCode: item.bookingCode),
          ),
        );
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF1F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: _buildImage(item.imageUrl, config),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.serviceName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.dateRange,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  priceDisplay,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.blue,
                                  ),
                                ),
                                // Hide explicit currency text if we used a symbol formatted string
                                if (currency == null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    item.currency,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: _StatusBadge(status: item.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? value, ServiceConfig? config) {
    if (value == null || value.isEmpty) {
      return Container(
        height: 120,
        color: Colors.blue.shade50,
        child: Icon(
          config?.fallbackIcon ?? Icons.travel_explore,
          size: 40,
          color: Colors.blue,
        ),
      );
    }
    if (value.startsWith('http')) {
      return Image.network(
        value,
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return Container(
      height: 120,
      color: Colors.blue.shade100,
      child: Icon(
        config?.fallbackIcon ?? Icons.travel_explore,
        size: 40,
        color: Colors.blue,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final map = {
      'paid': Colors.green,
      'completed': Colors.green,
      'pending': Colors.orange,
      'draft': Colors.orange,
      'cancelled': Colors.red,
    };
    final color = map[status.toLowerCase()] ?? Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ViewAllScreen extends StatelessWidget {
  final String serviceType;
  final List<BookingItem> items;
  final AppCurrency? currency;

  const _ViewAllScreen({
    required this.serviceType,
    required this.items,
    this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final config = kServiceConfig[serviceType];

    return Scaffold(
      appBar: AppBar(
        title: Text(config?.label ?? serviceType.toUpperCase()),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          return _BookingCardLight(item: items[i], currency: currency);
        },
      ),
    );
  }
}

class BookingItem {
  final String bookingCode;
  final String objectModel;
  final String serviceName;
  final String status;
  final String dateRange;
  final String totalFormatted;
  final String total; // Added raw total
  final String currency;
  final String? imageUrl;
  final DateTime startDate;
  final DateTime endDate;

  BookingItem({
    required this.bookingCode,
    required this.objectModel,
    required this.serviceName,
    required this.status,
    required this.dateRange,
    required this.totalFormatted,
    required this.total,
    required this.currency,
    this.imageUrl,
    required this.startDate,
    required this.endDate,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    final service = json['service'] as Map<String, dynamic>?;

    final start = DateTime.tryParse(json['start_date'] ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final end = DateTime.tryParse(json['end_date'] ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return BookingItem(
      bookingCode: json['code'] ?? '',
      objectModel: json['object_model'] ?? 'other',
      serviceName:
          service?['title'] ?? json['service_title'] ?? 'Booking',
      status: json['status'] ?? 'draft',
      dateRange:
          '${json['start_date'] ?? ''} → ${json['end_date'] ?? ''}',
      totalFormatted:
          json['total_formatted'] ?? '${json['total'] ?? 0}',
      total: '${json['total'] ?? 0}',
      currency: json['currency'] ?? 'VND',
      imageUrl: json['service_icon'],
      startDate: start,
      endDate: end,
    );
  }
}