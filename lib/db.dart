import 'package:flutter/material.dart';
import 'screens/customers_screen.dart';

void main() {
  runApp(const MNFashionApp());
}

class MNFashionApp extends StatelessWidget {
  const MNFashionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'M&N Fashion',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        fontFamily: 'Arial',
      ),
      home: const CustomersScreen(),
    );
  }
}
