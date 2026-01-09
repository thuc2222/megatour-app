import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:megatour_app/utils/context_extension.dart';
import '../../config/api_config.dart';

class CheckoutWebView extends StatefulWidget {
  final String bookingCode;

  CheckoutWebView({
    Key? key,
    required this.bookingCode,
  }) : super(key: key);

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final checkoutUrl = ApiConfig.webViewCheckout(widget.bookingCode);
_controller = WebViewController()
  ..loadRequest(Uri.parse(checkoutUrl));

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.checkout1),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
