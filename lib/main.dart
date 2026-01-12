import "package:flutter/material.dart";
import "screens/customers_screen.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SheinPricingApp());
}

class SheinPricingApp extends StatelessWidget {
  const SheinPricingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "M&N Fashion",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CustomersScreen(),
    );
  }
}
