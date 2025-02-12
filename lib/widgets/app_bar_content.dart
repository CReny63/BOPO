import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';

class AppBarContent extends StatelessWidget {
  const AppBarContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.menu,
              size: 13,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
            ),
            onPressed: () {
              // Implement your menu action here, if any.
            },
          ),
          // IconButton(
          //   icon: Icon(
          //     Icons.coffee,
          //     size: 13,
          //     color: Theme.of(context).appBarTheme.iconTheme?.color,
          //   ),
          //   onPressed: () {
          //     // Implement your custom coffee action here, if any.
          //   },
          // ),
          IconButton(
            icon: Icon(
              Icons.light_mode,
              size: 13,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
            ),
            onPressed: () {
              // Directly toggle the theme without showing a bottom sheet.
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
    );
  }
}
