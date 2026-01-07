import 'package:flutter/material.dart';
import 'package:megatour_app/utils/context_extension.dart';

class BookingSuccessScreen extends StatelessWidget {
  final String bookingCode;

  BookingSuccessScreen({Key? key, required this.bookingCode})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.bookingConfirmed)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(context.l10n.yourBookingIsConfirmed),
            SizedBox(height: 8),
            Text(
              bookingCode,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.done),
            ),
          ],
        ),
      ),
    );
  }
}
