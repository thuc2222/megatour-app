import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../../services/service_api.dart';
import '../booking/checkout_webview.dart';

class TourDetailScreen extends StatefulWidget {
  final int tourId;

  const TourDetailScreen({Key? key, required this.tourId}) : super(key: key);

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  final ServiceApi _api = ServiceApi();

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  bool _isSubmitting = false;

  DateTime? _selectedDate;
  final Map<String, int> _personCounts = {};
  final Set<int> _selectedExtras = {};

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadTour();
  }

  Future<void> _loadTour() async {
    try {
      final res = await _api.getServiceDetailRaw(
        id: widget.tourId,
        serviceType: 'tour',
      );

      if (!mounted) return;

      setState(() {
        _data = res['data'];
        _initPersons();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initPersons() {
    final persons = _data?['person_types'];
    if (persons is List) {
      for (final p in persons) {
        final min = int.tryParse(p['min'].toString()) ?? 0;
        _personCounts[p['name']] = min;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // BOOK TOUR (✅ MOBILE SAFE – /booking/create)
  // ---------------------------------------------------------------------------

  Future<void> _submitBooking() async {
    if (_selectedDate == null) {
      _snack('Please select a tour date', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // -----------------------------
      // PERSON TYPES
      // -----------------------------
      final Map<String, int> personTypes = {};
      _personCounts.forEach((name, qty) {
        if (qty > 0) personTypes[name] = qty;
      });

      // -----------------------------
      // EXTRA PRICE
      // -----------------------------
      final List<Map<String, dynamic>> extraPrice = [];
      final extras = _data?['extra_price'];
      if (extras is List) {
        for (final i in _selectedExtras) {
          extraPrice.add({
            'name': extras[i]['name'],
            'number': 1,
          });
        }
      }

      // -----------------------------
      // SEND TO CUSTOM API
      // -----------------------------
      final startDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
final endDate = DateFormat('yyyy-MM-dd')
    .format(_selectedDate!.add(const Duration(days: 1)));

final res = await _api.createBooking(
  objectModel: 'tour',
  objectId: widget.tourId,
  startDate: startDate,
  endDate: endDate,

  // 🔑 BookingCore REQUIRES items — send dummy
  items: {0: 1},
);

      setState(() => _isSubmitting = false);

      if (res['status'] == 1 && res['booking_code'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                CheckoutWebView(bookingCode: res['booking_code']),
          ),
        );
      } else {
        _snack(res['error'] ?? 'Booking failed', Colors.red);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _snack(e.toString(), Colors.red);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_data?['title'] ?? 'Tour'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGallery(),
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 16),
              _buildDatePicker(),
              const SizedBox(height: 16),
              _buildPersons(),
              const SizedBox(height: 16),
              _buildExtras(),
              const SizedBox(height: 16),
              _buildContent(),
              const SizedBox(height: 120),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI COMPONENTS (UNCHANGED)
  // ---------------------------------------------------------------------------

  Widget _buildGallery() {
    final gallery = _data?['gallery'];
    if (gallery is! List || gallery.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 220,
      child: PageView(
        children: gallery
            .map<Widget>(
              (img) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(img, fit: BoxFit.cover),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _data?['title'] ?? '',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_data?['location'] != null)
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                _data!['location']['name'] ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      leading: const Icon(Icons.calendar_month),
      title: Text(
        _selectedDate == null
            ? 'Select tour date'
            : DateFormat('MMM dd, yyyy').format(_selectedDate!),
      ),
      trailing: const Icon(Icons.edit),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) setState(() => _selectedDate = d);
      },
    );
  }

  Widget _buildPersons() {
    final persons = _data?['person_types'];
    if (persons is! List) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Participants',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...persons.map<Widget>((p) {
          final name = p['name'];
          final price = p['price'];
          final count = _personCounts[name] ?? 0;
          final max = int.tryParse(p['max'].toString()) ?? 99;

          return ListTile(
            title: Text(name),
            subtitle: Text('\$$price'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: count > 0
                      ? () => setState(
                          () => _personCounts[name] = count - 1)
                      : null,
                ),
                Text('$count'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: count < max
                      ? () => setState(
                          () => _personCounts[name] = count + 1)
                      : null,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExtras() {
    if (_data?['enable_extra_price'] != 1) return const SizedBox.shrink();

    final extras = _data?['extra_price'];
    if (extras is! List || extras.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Extras',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ...extras.asMap().entries.map((e) {
          return CheckboxListTile(
            title: Text(e.value['name']),
            subtitle: Text('\$${e.value['price']}'),
            value: _selectedExtras.contains(e.key),
            onChanged: (v) {
              setState(() {
                v == true
                    ? _selectedExtras.add(e.key)
                    : _selectedExtras.remove(e.key);
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildContent() {
    return HtmlWidget(_data?['content'] ?? '');
  }

  Widget _buildBottomBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitBooking,
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('BOOK NOW'),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
}
