import 'package:flutter/material.dart';
import 'package:megatour_app/utils/context_extension.dart';

class SearchTab extends StatelessWidget {
  const SearchTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: const Center(
        child: Text('Search Tab - Will be implemented'),
      ),
    );
  }
}