// lib/screens/test_api_screen.dart
// Use this screen to test API directly

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:megatour_app/utils/context_extension.dart';

class TestApiScreen extends StatefulWidget {
  TestApiScreen({Key? key}) : super(key: key);

  @override
  State<TestApiScreen> createState() => _TestApiScreenState();
}

class _TestApiScreenState extends State<TestApiScreen> {
  String _result = 'Tap button to test API';
  bool _loading = false;

  Future<void> _testLogin() async {
    setState(() {
      _loading = true;
      _result = 'Testing...';
    });

    try {
      // Test 1: Check if server is reachable
      print('Testing API connection...');
      
      final url = 'http://dev.bookingcore.co/api/auth/login';
      print('URL: $url');

      // Prepare request
      final body = {
        'email': 'admin@dev.com',
        'password': 'admin1234',
      };
      
      final encodedBody = body.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      print('Request body: $encodedBody');

      // Make request
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: encodedBody,
      ).timeout(Duration(seconds: 30));

      print('Status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = 'SUCCESS!\n\n'
              'Status Code: ${response.statusCode}\n'
              'Response: ${jsonEncode(data)}\n\n'
              'Token: ${data['access_token'] ?? 'No token'}';
        });
      } else {
        setState(() {
          _result = 'FAILED!\n\n'
              'Status Code: ${response.statusCode}\n'
              'Response: ${response.body}';
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _result = 'ERROR!\n\n$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _testConfigs() async {
    setState(() {
      _loading = true;
      _result = 'Testing configs...';
    });

    try {
      final response = await http.get(
        Uri.parse('http://dev.bookingcore.co/api/configs'),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: 30));

      print('Status: ${response.statusCode}');
      print('Response: ${response.body}');

      setState(() {
        _result = 'CONFIG TEST\n\n'
            'Status: ${response.statusCode}\n'
            'Response: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...';
      });
    } catch (e) {
      setState(() {
        _result = 'ERROR!\n\n$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.testApi),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _loading ? null : _testConfigs,
              child: Text(context.l10n.testConfigsApiNoAuth),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _testLogin,
              child: Text(context.l10n.testLoginApi),
            ),
            SizedBox(height: 24),
            if (_loading)
              Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _result,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}