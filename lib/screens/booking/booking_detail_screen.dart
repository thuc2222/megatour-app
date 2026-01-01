import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

const String API_BASE_URL = 'https://megatour.vn/api/';

class BookingDetailScreen extends StatefulWidget {
  final String bookingCode;

  const BookingDetailScreen({
    Key? key,
    required this.bookingCode,
  }) : super(key: key);

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  late Future<BookingDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadDetail();
  }

  Future<BookingDetail> _loadDetail() async {
    final res = await http.get(
      Uri.parse('${API_BASE_URL}user/booking/${widget.bookingCode}'),
      headers: {
        'Accept': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load booking');
    }

    final decoded = jsonDecode(res.body);

    if (decoded['status'] != 1) {
      throw Exception('Booking not found');
    }

    return BookingDetail.fromJson(decoded);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadDetail();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Booking Details'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<BookingDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('Booking not found'));
            }

            final detail = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _headerImage(detail.service.image),
                _statusBadge(detail.booking.status),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    detail.service.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${detail.booking.startDate} → ${detail.booking.endDate}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),

                if (detail.service.location != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Text(detail.service.location!),
                      ],
                    ),
                  ),

                _section(
                  title: 'Booking Summary',
                  children: [
                    _row('Status', detail.booking.status.toUpperCase()),
                    _row(
                      'Guests',
                      '${detail.booking.adults} Adults, ${detail.booking.children} Children',
                    ),
                    _row('Total', detail.booking.totalFormatted),
                  ],
                ),

                if (detail.items.isNotEmpty)
                  _section(
                    title: 'Items',
                    children: detail.items
                        .map(
                          (i) => _row(
                            '${i.quantity} × ${i.name}',
                            i.price ?? '',
                          ),
                        )
                        .toList(),
                  ),

                if (detail.booking.isPayable)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingPaymentWebView(
                              bookingCode: detail.booking.code,
                            ),
                          ),
                        );
                        _reload();
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: const Text('Pay Now'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _headerImage(String? image) {
    if (image == null || image.isEmpty) {
      return Container(
        height: 220,
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 64),
      );
    }

    return Image.network(
      image,
      height: 220,
      width: double.infinity,
      fit: BoxFit.cover,
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
        return Colors.green;
      case 'processing':
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}

/// ---------------------------------------------------------------------------
/// PAYMENT WEBVIEW (webview_flutter v4+)
/// ---------------------------------------------------------------------------

class BookingPaymentWebView extends StatefulWidget {
  final String bookingCode;

  const BookingPaymentWebView({
    Key? key,
    required this.bookingCode,
  }) : super(key: key);

  @override
  State<BookingPaymentWebView> createState() => _BookingPaymentWebViewState();
}

class _BookingPaymentWebViewState extends State<BookingPaymentWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(
          'https://megatour.vn/booking/${widget.bookingCode}/checkout',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: WebViewWidget(controller: _controller),
    );
  }
}

/// ---------------------------------------------------------------------------
/// DATA MODELS (NULL SAFE)
/// ---------------------------------------------------------------------------

class BookingDetail {
  final Booking booking;
  final Service service;
  final List<BookingItem> items;

  BookingDetail({
    required this.booking,
    required this.service,
    required this.items,
  });

  factory BookingDetail.fromJson(Map<String, dynamic> json) {
    return BookingDetail(
      booking: Booking.fromJson(json['booking']),
      service: Service.fromJson(json['service']),
      items: (json['items'] as List? ?? [])
          .map((e) => BookingItem.fromJson(e))
          .toList(),
    );
  }
}

class Booking {
  final String code;
  final String status;
  final String startDate;
  final String endDate;
  final int adults;
  final int children;
  final String totalFormatted;

  Booking({
    required this.code,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.adults,
    required this.children,
    required this.totalFormatted,
  });

  bool get isPayable =>
      status == 'draft' || status == 'pending' || status == 'processing';

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      code: json['code'] ?? '',
      status: json['status'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      adults: json['adults'] ?? 0,
      children: json['children'] ?? 0,
      totalFormatted:
          json['total_formatted'] ??
          json['total']?.toString() ??
          '',
    );
  }
}

class Service {
  final String title;
  final String? image;
  final String? location;

  Service({
    required this.title,
    this.image,
    this.location,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      title: json['title'] ?? '',
      image: json['image'],
      location: json['location'],
    );
  }
}

class BookingItem {
  final String name;
  final int quantity;
  final String? price;

  BookingItem({
    required this.name,
    required this.quantity,
    this.price,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 1,
      price: json['price'],
    );
  }
}
