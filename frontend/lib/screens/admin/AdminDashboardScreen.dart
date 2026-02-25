import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final results = await Future.wait([
        http.get(Uri.parse('${auth.apiUrl}/api/admin/revenue?range=$_range')),
        http.get(Uri.parse('${auth.apiUrl}/api/admin/stats')),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        if (mounted) {
          setState(() {
            _revenueData = json.decode(results[0].body);
            _stats = json.decode(results[1].body);
          });
        }
      }
    } catch (e) {
      debugPrint("Dashboard Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: !isDesktop ? AppBar(
                title: const Text("MusicX Analytics", style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.white,
                elevation: 0,
              ) : null,
              drawer: !isDesktop ? Drawer(child: _buildSidebarContent()) : null,
              body: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildStatCards(isDesktop),
                    const SizedBox(height: 32),
                    _buildChartSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 📈 LINE CHART LOGIC (Clean Axis & Pro Design) ---

  LineChartData _mainData() {
    if (_revenueData.isEmpty) return LineChartData();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            reservedSize: 32,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 55, // Khoảng trống rộng để không đè lên biểu đồ
            getTitlesWidget: (value, meta) {
              // Chỉ hiển thị nhãn tại các mốc chia đều (không lấy số lẻ cụ thể)
              if (value == meta.max || value == meta.min) return const SizedBox();
              
              String text = value >= 1000000 
                  ? '${(value / 1000000).toStringAsFixed(1)}M' 
                  : '${(value / 1000).toInt()}k';
                  
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: Colors.black.withOpacity(0.8),
          tooltipRoundedRadius: 8,
          getTooltipItems: (spots) => spots.map((s) {
            final label = _revenueData[s.x.toInt()]['label'];
            return LineTooltipItem(
              "$label\n${NumberFormat("#,###").format(s.y)}₫",
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            );
          }).toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: _revenueData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value['amount'].toDouble())).toList(),
          isCurved: true, // Đường cong mềm mại như mẫu
          color: Colors.black,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Colors.black.withOpacity(0.03)),
        ),
      ],
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    int index = value.toInt();
    if (index < 0 || index >= _revenueData.length) return const SizedBox();
    
    String label = _revenueData[index]['label'] ?? "";
    
    // Rút gọn nhãn từ Backend (W10, Mar...)
    if (_range == 'week' && label.contains('-W')) {
       label = label.split('-').last;
    } else if (_range == 'month' && label.length >= 7) {
       try {
         label = DateFormat('MMM').format(DateTime.parse("$label-01"));
       } catch (_) {}
    }

    // Chỉ hiện nhãn mỗi 4 tiếng cho Day để tránh đè nhau
    if (_range == 'day' && index % 4 != 0) return const SizedBox();

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  // --- 🧱 UI COMPONENTS ---

  Widget _buildSidebar() => Container(width: 260, color: Colors.black, child: _buildSidebarContent());

  Widget _buildSidebarContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MUSICX ADMIN", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          _sidebarItem(Icons.dashboard, "Dashboard", isSelected: true),
          _sidebarItem(Icons.album, "Albums", onTap: () => Navigator.pushNamed(context, '/manage-albums')),
          _sidebarItem(Icons.mic, "Artists", onTap: () => Navigator.pushNamed(context, '/manage-artists')),
          _sidebarItem(Icons.category, "Genres", onTap: () => Navigator.pushNamed(context, '/manage-genres')),
          _sidebarItem(Icons.shopping_cart, "Orders", onTap: () => Navigator.pushNamed(context, '/manage-orders')),
          _sidebarItem(Icons.person, "Users", onTap: () => Navigator.pushNamed(context, '/manage-users')),
          const Spacer(),
          _sidebarItem(Icons.logout, "Logout", onTap: () => Provider.of<AuthProvider>(context, listen: false).logout()),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, {bool isSelected = false, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.grey[500], size: 20),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[500], fontSize: 14)),
      selected: isSelected,
      selectedTileColor: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Analytics Overview", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: ['day', 'week', 'month'].map((r) {
              bool isSel = _range == r;
              return GestureDetector(
                onTap: () { setState(() => _range = r); _fetchData(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.black : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    r.toUpperCase(),
                    style: TextStyle(color: isSel ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(bool isDesktop) {
    final currency = NumberFormat("#,###", "vi_VN");
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 3 : 1,
      childAspectRatio: isDesktop ? 2.8 : 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _statCard("Revenue", "${currency.format(_stats['totalRevenue'])}₫", Icons.payments, Colors.blue),
        _statCard("Orders", _stats['totalOrders'].toString(), Icons.shopping_bag, Colors.orange),
        _statCard("Users", _stats['totalUsers'].toString(), Icons.people, Colors.green),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Revenue Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 32),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : LineChart(_mainData()),
          ),
        ],
      ),
    );
  }
}