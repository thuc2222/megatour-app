import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import 'package:megatour_app/utils/context_extension.dart';

// --- Constants for Theme ---
Color kPrimaryBlue = Color(0xFF0A2342);
Color kAccentTeal = Color(0xFF00A896);
Color kAccentOrange = Color(0xFFFA824C);
Color kLightGreyBg = Color(0xFFF5F7FA);

// Gradient for the main ticket
LinearGradient kTicketGradient = LinearGradient(
  colors: [kPrimaryBlue, kAccentTeal],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

String API_BASE_URL = 'https://megatour.vn/api/';

// --- Currency Helper ---
class AppCurrency {
  final String symbol;
  final String format;
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
      symbol: json['symbol'] ?? '\$',
      format: json['currency_format'] ?? 'left',
      thousand: json['currency_thousand'] ?? '.',
      decimal: json['currency_decimal'] ?? ',',
      precision: int.tryParse('${json['currency_no_decimal']}') ?? 2,
    );
  }

  String formatPrice(dynamic price) {
    double amount = double.tryParse('$price') ?? 0.0;
    String value = amount.toStringAsFixed(precision);
    
    List<String> parts = value.split('.');
    String integerPart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '';

    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String Function(Match) mathFunc = (Match match) => '${match[1]}$thousand';
    integerPart = integerPart.replaceAllMapped(reg, mathFunc);

    String formattedNum = decimalPart.isNotEmpty 
        ? '$integerPart$decimal$decimalPart' 
        : integerPart;

    return format == 'right' ? '$formattedNum$symbol' : '$symbol$formattedNum';
  }
}

class BookingDetailScreen extends StatefulWidget {
  final String bookingCode;

  BookingDetailScreen({
    Key? key,
    required this.bookingCode,
  }) : super(key: key);

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _booking;
  String? _error;
  AppCurrency? _appCurrency;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    final token = auth.token;

    if (token == null) {
      setState(() {
        _error = 'Please login to continue';
        _loading = false;
      });
      return;
    }

    try {
      // 1. Fetch Configs
      try {
        final configRes = await http.get(Uri.parse('${API_BASE_URL}configs'));
        if (configRes.statusCode == 200) {
          final json = jsonDecode(configRes.body);
          final List currencies = json['currency'] ?? [];
          final mainCurrData = currencies.firstWhere(
              (element) => element['is_main'] == 1,
              orElse: () => currencies.isNotEmpty ? currencies.first : null);
          
          if (mainCurrData != null) {
            _appCurrency = AppCurrency.fromJson(mainCurrData);
          }
        }
      } catch (e) {
        debugPrint('Error loading currency config: $e');
      }

      // 2. Fetch Booking Details
      final url = Uri.parse('${API_BASE_URL}booking/${widget.bookingCode}');
      final res = await http.get(url, headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
      });

      final body = json.decode(res.body);
      if (res.statusCode != 200) {
        throw Exception(body['message'] ?? 'Failed to load booking');
      }

      Map<String, dynamic>? finalBookingData;
      if (body['data'] != null) {
        if (body['data'] is List) {
          final List listData = body['data'];
          if (listData.isNotEmpty) finalBookingData = listData[0];
        } else {
          finalBookingData = body['data'];
        }
      } else if (body['id'] != null || body['code'] != null) {
        finalBookingData = body;
      } else if (body['booking'] != null) {
        finalBookingData = body['booking'];
      }

      if (finalBookingData == null) {
        throw Exception('Booking data is empty or invalid format');
      }

      setState(() {
        _booking = finalBookingData;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightGreyBg,
      body: Stack(
        children: [
          // Ambient Background
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryBlue.withOpacity(0.1), kLightGreyBg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _buildRedesignedContent(),
          ),
          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: kPrimaryBlue),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedesignedContent() {
    if (_booking == null) return Center(child: Text(context.l10n.noDataFound));
    final b = _booking!;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 20.0),
            child: Text(
              context.l10n.bookingDetails,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: kPrimaryBlue),
            ),
          ),
          // Hero Ticket
          _buildMainTicketCard(b),
          SizedBox(height: 24),
          
          // Secondary Info
          _buildInfoSection(
            title: context.l10n.serviceInformation,
            icon: Icons.tour,
            children: [
               _row('Service Type', b['object_model']?.toString() ?? 'N/A', isBold: true),
               _row('Service Ref ID', '#${b['object_id']?.toString() ?? ''}'),
            ]
          ),

          _buildInfoSection(
            title: context.l10n.paymentSummary,
            icon: Icons.payment,
            children: [
              _row('Total Amount', formatMoney(b['total']), isBold: true, valueColor: kPrimaryBlue),
              _row('Amount Paid', formatMoney(b['paid'])),
              Divider(height: 24),
              _row('Due Now', formatMoney(b['pay_now']), isBold: true, valueColor: kAccentOrange),
            ]
          ),
           SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMainTicketCard(Map<String, dynamic> b) {
    final dfMonth = DateFormat('MMM dd');
    final dfYear = DateFormat('yyyy');

    String formatMonth(String? dateStr) {
      if (dateStr == null) return '--';
      try { return dfMonth.format(DateTime.parse(dateStr)); } catch (_) { return dateStr; }
    }
    String formatYear(String? dateStr) {
        if (dateStr == null) return '';
        try { return dfYear.format(DateTime.parse(dateStr)); } catch (_) { return ''; }
    }

    String status = b['status']?.toString().toLowerCase() ?? 'unknown';
    Color statusColor = (status == '1' || status == 'confirmed') ? kAccentTeal : kAccentOrange;
    String statusText = (status == '1' || status == 'confirmed') ? 'CONFIRMED' : 'PENDING';

    return Container(
      decoration: BoxDecoration(
        gradient: kTicketGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: kPrimaryBlue.withOpacity(0.3), blurRadius: 15, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circle
            Positioned(top: -50, right: -50, child: CircleAvatar(radius: 60, backgroundColor: Colors.white.withOpacity(0.1))),
            
            Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Align everything to the left
                children: [
                  // --- HEADER ROW: Label + Badge ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(
                         context.l10n.bookingReference, 
                         style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, letterSpacing: 1)
                       ),
                       _buildStatusBadge(statusText, statusColor),
                    ],
                  ),
                  
                  SizedBox(height: 8),

                  // --- BOOKING CODE ROW (Full Width) ---
                  // Now on its own line, it won't be covered by the badge
                  Text(
                    b['code']?.toString() ?? '',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 22, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.2
                    ),
                    maxLines: 2, // Allow wrapping if the code is extremely long
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: 30),
                  
                  // --- DATES ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDateBlock("CHECK-IN", formatMonth(b['start_date']), formatYear(b['start_date'])),
                      Icon(Icons.arrow_right_alt, color: Colors.white, size: 30),
                      _buildDateBlock("CHECK-OUT", formatMonth(b['end_date']), formatYear(b['end_date']), alignRight: true),
                    ],
                  ),
                  
                  SizedBox(height: 30),
                  
                  // --- DIVIDER LINE ---
                  Row(children: List.generate(30, (index) => Expanded(child: Container(height: 1, color: index % 2 == 0 ? Colors.white.withOpacity(0.5) : Colors.transparent)))),
                  
                  SizedBox(height: 20),
                  
                  // --- GUEST INFO ---
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.white.withOpacity(0.2), child: Icon(Icons.person, color: Colors.white)),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b['first_name'] ?? ''} ${b['last_name'] ?? ''}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('${b['total_guests'] ?? '1'} Guests', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBlock(String label, String date, String year, {bool alignRight = false}) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
        SizedBox(height: 4),
        Text(date, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(year, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
           Icon(Icons.check_circle, color: color, size: 16),
           SizedBox(width: 4),
           Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInfoSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: kPrimaryBlue.withOpacity(0.7)),
              SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kPrimaryBlue)),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // FIXED: Renamed from _buildRow to _row to match the calls above
  Widget _row(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                fontSize: isBold ? 16 : 15,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatMoney(dynamic value) {
    if (_appCurrency != null) {
      return _appCurrency!.formatPrice(value);
    }
    return '\$${value ?? 0}';
  }
}