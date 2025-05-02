import 'package:flutter/material.dart';
import '../widgets/custom_navigation_drawer.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      drawer: const AppDrawer(),
      body: const Center(child: Text('Welcome to the Home Screen!')),
    );
  }
}
