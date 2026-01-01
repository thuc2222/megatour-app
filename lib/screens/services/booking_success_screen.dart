class BookingSuccessScreen extends StatelessWidget {
  final String roomTitle;
  final double totalPrice;

  const BookingSuccessScreen({required this.roomTitle, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text("Reservation Received!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("We have received your booking for $roomTitle."),
              Text("Total Amount: \$${totalPrice.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              const Text("Please wait for staff confirmation for your offline payment.", textAlign: TextAlign.center),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text("Back to Home"),
              )
            ],
          ),
        ),
      ),
    );
  }
}