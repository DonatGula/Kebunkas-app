import 'package:flutter/material.dart';
import 'package:appjeruk/main.dart';
import 'package:appjeruk/theme_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Tunggu 3 detik lalu pindah ke halaman utama
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // Warna hijau pucat sesuai background logo
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO BARU PAMAN
            Image.asset(
              'assets/images/logo.png',
              width: 180,
            ),
            const SizedBox(height: 20),
            const Text(
              "Kebun Kas",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Nunito',
                color: Color(0xFF2E7D32),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            const CircularProgressIndicator(
              color: Color(0xFF2E7D32),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}