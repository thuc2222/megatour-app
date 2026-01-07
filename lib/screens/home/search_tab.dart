import 'package:flutter/material.dart';
import 'package:megatour_app/utils/context_extension.dart';

class SearchTab extends StatelessWidget {
  SearchTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.search),
      ),
      body: Center(
        child: Text(context.l10n.searchTabWillBeImplemented),
      ),
    );
  }
}