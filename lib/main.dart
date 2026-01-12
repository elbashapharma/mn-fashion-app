import "package:flutter/material.dart";
import "screens/customers_screen.dart";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MNFashionApp());
}

class MNFashionApp extends StatelessWidget {
  const MNFashionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "M&N Fashion",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
        fontFamily: "Arial",
      ),
      // ✅ بدون const (عشان ما يطلع Error لو الشاشة مش const)
      home: CustomersScreen(),
    );
  }
}

