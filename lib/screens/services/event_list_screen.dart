import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({Key? key}) : super(key: key);

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  // ----------------------------
  // SEARCH & FILTER STATE
  // ----------------------------
  String? location;
  DateTime? fromDate;
  DateTime? toDate;
  RangeValues priceRange = const RangeValues(193, 2000); // Defaults from API
  double reviewScore = 0;
  final Set<int> selectedTerms = {};

  // ----------------------------
  // UI STATE
  // ----------------------------
  bool isLoading = false;
  List<dynamic> events = [];

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  String formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  // ----------------------------
  // API LOGIC
  // ----------------------------
  Future<void> fetchEvents() async {
  setState(() => isLoading = true);
  try {
    // Correct search parameters for GET request
    final Map<String, String> queryParams = {
      if (location != null && location!.isNotEmpty) 's': location!,
      if (fromDate != null) 'start': formatDate(fromDate!),
      if (toDate != null) 'end': formatDate(toDate!),
      'price_range[0]': priceRange.start.round().toString(),
      'price_range[1]': priceRange.end.round().toString(),
    };

    // Use /api/event/search (GET) instead of /api/event/form-search (POST)
    final uri = Uri.https('megatour.vn', '/api/event/search', queryParams);
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final body = json.decode(res.body);
      final rawData = body['data'];

      setState(() {
        // Handle Laravel pagination wrapper
        if (rawData is Map && rawData.containsKey('data')) {
          events = rawData['data']; 
        } else {
          events = rawData is List ? rawData : [];
        }
      });
    }
  } catch (e) {
    debugPrint("Error: $e");
    setState(() => events = []);
  } finally {
    setState(() => isLoading = false);
  }
}

  // ----------------------------
  // UI COMPONENTS
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Events")),
      body: Column(
        children: [
          _buildSearchForm(),
          _buildFilters(),
          Expanded(child: _buildEventList()),
        ],
      ),
    );
  }

  Widget _buildSearchForm() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: "Location",
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => location = v,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fromDate == null ? "From" : formatDate(fromDate!)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(toDate == null ? "To" : formatDate(toDate!)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: fetchEvents,
              child: const Text("Search Events"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return ExpansionTile(
      title: const Text("Filters & Attributes"),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Price Range: \$${priceRange.start.round()} - \$${priceRange.end.round()}"),
              RangeSlider(
                min: 193, // Based on API Filter Response
                max: 2000,
                values: priceRange,
                onChanged: (v) => setState(() => priceRange = v),
              ),
              const Text("Minimum Review Score"),
              Slider(
                min: 0,
                max: 5,
                divisions: 5,
                label: reviewScore.round().toString(),
                value: reviewScore,
                onChanged: (v) => setState(() => reviewScore = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventList() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (events.isEmpty) return const Center(child: Text("No events found"));

    return ListView.builder(
    itemCount: events.length,
    itemBuilder: (_, i) {
      final e = events[i];
      final int eventId = int.tryParse(e['id'].toString()) ?? 0;

      return GestureDetector(
        onTap: () {
          // Explicitly push EventDetailScreen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(eventId: eventId),
            ),
          );
        },
        child: Card(
          // ... rest of your UI
        ),
      );
    },
  );
  }

  Future<void> _pickDate(bool isFrom) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
    );
    if (date != null) setState(() => isFrom ? fromDate = date : toDate = date);
  }
}