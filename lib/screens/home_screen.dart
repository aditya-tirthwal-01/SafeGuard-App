import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final phoneController = TextEditingController();
  bool isSending = false;
  bool isPressed = false;

  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadEmergencyNumber();
  }

  // 🔥 LOAD NUMBER
  Future<void> loadEmergencyNumber() async {
    String uid = user!.uid;

    var doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (doc.exists && doc.data()!["emergency"] != null) {
      phoneController.text = doc.data()!["emergency"];
    } else {
      phoneController.text = "";
    }
  }

  // 🔥 SAVE NUMBER
  Future<void> saveEmergencyNumber() async {
    String uid = user!.uid;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .set({
      "emergency": phoneController.text,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Number Saved ✅")),
    );

    setState(() {});
  }

  // 🌐 INTERNET CHECK
  Future<bool> isInternetAvailable() async {
    var result = await Connectivity().checkConnectivity();

    if (result == ConnectivityResult.none) return false;

    try {
      final lookup = await InternetAddress.lookup('google.com');
      return lookup.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // 📍 LOCATION
  Future<String> getLocationLink() async {

    bool serviceEnabled;
    LocationPermission permission;

    // 🔥 CHECK SERVICE
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return "Location OFF (Turn on GPS)";
    }

    // 🔥 CHECK PERMISSION
    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return "Permission permanently denied";
    }

    // 📍 GET LOCATION
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));

      return "https://maps.google.com/?q=${position.latitude},${position.longitude}";
    } catch (e) {
      return "Location failed";
    }
  }

  // 📞 CALL
  Future<void> makeCall(String number) async {
    final Uri uri = Uri.parse("tel:$number");
    await launchUrl(uri);
  }

  // 📩 SMS
  Future<void> sendSMS(String number, String message) async {
    final Uri uri = Uri.parse("sms:$number?body=$message");
    await launchUrl(uri);
  }

  // 🚨 SOS FUNCTION
  Future<void> sendSOS() async {

    if (phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add emergency number")),
      );
      return;
    }

    setState(() => isSending = true);

    try {
      String number = phoneController.text.trim();

      if (!number.startsWith("+91")) {
        number = "+91$number";
      }

      String location = await getLocationLink();

      String message =
          "🚨 HELP! I need assistance\n📍 Location: $location";

      bool isOnline = await isInternetAvailable();

      if (isOnline) {
        // 🟢 ONLINE
        final response = await http.post(
          Uri.parse("https://safeguard-backend-zd7u.onrender.com/sos"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "phone": number,
            "message": message,
          }),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SOS via Internet 🌐")),
          );
          setState(() => isSending = false);
          return;
        }
      }

      // 🔴 OFFLINE
      await makeCall(number);
      await sendSMS(number, message);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("SOS via Phone 📞")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isSending = false);
  }

  // 🔓 LOGOUT
  void logout() async {
    await FirebaseAuth.instance.signOut();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.black,

      // 🔥 DRAWER
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF1A0000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [

              // HEADER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 50, bottom: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.redAccent],
                  ),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.red),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user?.displayName ?? user?.email ?? "User",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // NUMBER SECTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: phoneController.text.isEmpty
                    ? Column(
                  children: [
                    TextField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Enter Emergency Number",
                        hintStyle:
                        const TextStyle(color: Colors.grey),
                        prefixIcon:
                        const Icon(Icons.phone, color: Colors.red),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: saveEmergencyNumber,
                      child: const Text("Add Number"),
                    ),
                  ],
                )
                    : Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          phoneController.text,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit,
                            color: Colors.white),
                        onPressed: () {
                          setState(() {
                            phoneController.text = "";
                          });
                        },
                      )
                    ],
                  ),
                ),
              ),

              const Spacer(),

              ElevatedButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
              ),
            ],
          ),
        ),
      ),

      // 🔴 APPBAR
      appBar: AppBar(
        title: const Text("SafeGuard"),
        backgroundColor: Colors.red,
      ),

      // 🔥 PREMIUM UI
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black, Color(0xFF1A0000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),

          child: Center( // 🔥 IMPORTANT
            child: Column(
              mainAxisSize: MainAxisSize.min, // 🔥 FIX
              children: [

                const Text(
                  "EMERGENCY SOS",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                GestureDetector(
                  onTapDown: (_) => setState(() => isPressed = true),
                  onTapUp: (_) {
                    setState(() => isPressed = false);
                    sendSOS();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: isPressed
                        ? (Matrix4.identity()..scale(0.9))
                        : Matrix4.identity(),
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Colors.red, Colors.redAccent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.7),
                          blurRadius: 30,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: isSending
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                        "SOS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Tap to send emergency alert",
                  style: TextStyle(color: Colors.white70),
                ),

              ],
            ),
          ),
        ),
    );
  }
}