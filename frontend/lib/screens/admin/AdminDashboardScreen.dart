import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // 
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _revenueData = [];
  Map<String, dynamic> _stats = {'totalRevenue': 0, 'totalOrders': 0, 'totalUsers': 0};
  bool _isLoading = true;
  String _range = 'week';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String apiUrl = auth.apiUrl;

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$apiUrl/api/admin/revenue?range=$_range')),
        http.get(Uri.parse('$apiUrl/api/admin/stats')),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        setState(() {
          _revenueData = json.decode(results[0].body);
          _stats = json.decode(results[1].body);
        });
      }
    } catch (e) {
      debugPrint("Dashboard Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Sidebar (Dành riêng cho Desktop)
          _buildSidebar(),
          
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildStatCards(),
                  const SizedBox(height: 32),
                  _buildChartSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MUSICX ADMIN", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          _sidebarItem(Icons.dashboard, "Dashboard", isSelected: true),
          _sidebarItem(Icons.album, "Manage Albums", onTap: () => Navigator.pushNamed(context, '/manage-albums')),
          _sidebarItem(Icons.mic, "Manage Artists", onTap: () => Navigator.pushNamed(context, '/manage-artists')),
          _sidebarItem(Icons.category, "Manage Genres", onTap: () => Navigator.pushNamed(context, '/manage-genres')),
          _sidebarItem(Icons.shopping_cart, "Manage Orders", onTap: () => Navigator.pushNamed(context, '/manage-orders')),
          _sidebarItem(Icons.person, "Manage Users", onTap: () => Navigator.pushNamed(context, '/manage-users')),
          const Spacer(),
          _sidebarItem(Icons.logout, "Logout", onTap: () => Provider.of<AuthProvider>(context, listen: false).logout()),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, {bool isSelected = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.grey),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.1),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Analytics Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Row(
          children: ['day', 'week', 'month'].map((r) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(r.toUpperCase()),
              selected: _range == r,
              onSelected: (val) {
                if (val) {
                  setState(() => _range = r);
                  _fetchData();
                }
              },
              selectedColor: Colors.black,
              labelStyle: TextStyle(color: _range == r ? Colors.white : Colors.black),
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCards() {
    final currency = NumberFormat("#,###", "vi_VN");
    return LayoutBuilder(builder: (context, constraints) {
      return Row(
        children: [
          _statCard("Total Revenue", "${currency.format(_stats['totalRevenue'])}₫", Icons.payments, Colors.blue),
          _statCard("Total Orders", _stats['totalOrders'].toString(), Icons.shopping_bag, Colors.orange),
          _statCard("Users", _stats['totalUsers'].toString(), Icons.people, Colors.green),
        ],
      );
    });
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : LineChart(_mainData()),
    );
  }

  LineChartData _mainData() {
    if (_revenueData.isEmpty) return LineChartData();
    
    return LineChartData(
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: const FlTitlesData(show: true, rightTitles: AxisTitles(), topTitles: AxisTitles()),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _revenueData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['amount'].toDouble())).toList(),
          isCurved: true,
          color: Colors.black,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Colors.black.withOpacity(0.05)),
        ),
      ],
    );
  }
}