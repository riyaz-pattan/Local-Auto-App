import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('callLogs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading analytics', style: TextStyle(color: Theme.of(context).colorScheme.error)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final totalCalls = docs.length;
        final driverCallCounts = <String, int>{};
        
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final driverId = data['driverId'] as String? ?? 'unknown';
          driverCallCounts[driverId] = (driverCallCounts[driverId] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact Single-Line Metrics
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactMetric(context, 'Total Calls', '$totalCalls', Icons.phone_in_talk, Colors.blue),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _buildCompactMetric(context, 'Active Drivers', '${driverCallCounts.length}', Icons.people_alt, Colors.green),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Driver Data', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ),
            
            Expanded(
              child: driverCallCounts.isEmpty 
                ? Center(child: Text('No call data available.', style: TextStyle(color: Theme.of(context).colorScheme.secondary)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: driverCallCounts.keys.length,
                    itemBuilder: (context, index) {
                      final driverId = driverCallCounts.keys.elementAt(index);
                      final count = driverCallCounts[driverId];

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('drivers').doc(driverId).get(),
                        builder: (context, driverSnapshot) {
                          String name = 'Deleted/Unknown Driver';
                          String? photoUrl;
                          
                          if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
                            final driverData = driverSnapshot.data!.data() as Map<String, dynamic>?;
                            if (driverData != null) {
                              name = driverData['name'] ?? name;
                              photoUrl = driverData['profilePhotoUrl'];
                            }
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                                child: photoUrl == null ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary) : null,
                              ),
                              title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$count', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactMetric(BuildContext context, String title, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            Text(title, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}
