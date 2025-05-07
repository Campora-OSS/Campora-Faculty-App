import 'package:flutter/material.dart';
import '../widgets/custom_navigation_drawer.dart';

class UnderConstructionScreen extends StatelessWidget {
  const UnderConstructionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      drawer: isWeb ? null : const AppDrawer(), // Drawer for mobile only
      body:
          isWeb
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppDrawer(), // Persistent sidebar for web
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.construction,
                            size: 100,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This feature is under maintenance.',
                            style: TextStyle(fontSize: isWeb ? 20 : 18),
                          ),
                          Text(
                            'Please check back later.',
                            style: TextStyle(
                              fontSize: isWeb ? 18 : 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
              : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.construction, size: 100, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'This feature is under maintenance.',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      'Please check back later.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
    );
  }
}
