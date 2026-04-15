import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesignShowcasePage extends StatefulWidget {
  const DesignShowcasePage({super.key});

  @override
  State<DesignShowcasePage> createState() => _DesignShowcasePageState();
}

class _DesignShowcasePageState extends State<DesignShowcasePage> {
  int _selectedStyle = 0; // 0: Stealth Carbon, 1: Minimalist Glass, 2: Retro Arcade, 3: Classic Analog

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBgColor(),
      appBar: AppBar(
        title: Text('DESIGN CONCEPTS', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.palette),
            onSelected: (val) => setState(() => _selectedStyle = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Text('Stealth Carbon')),
              const PopupMenuItem(value: 1, child: Text('Minimalist Glass')),
              const PopupMenuItem(value: 2, child: Text('Retro Arcade')),
              const PopupMenuItem(value: 3, child: Text('Classic Analog')),
            ],
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 40),
            _buildMainGauge(),
            const SizedBox(height: 40),
            _buildDataGrid(),
            const SizedBox(height: 40),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Color _getBgColor() {
    switch (_selectedStyle) {
      case 0: return const Color(0xFF121212);
      case 1: return const Color(0xFF0F172A);
      case 2: return Colors.black;
      case 3: return const Color(0xFF1C1C1C);
      default: return Colors.black;
    }
  }

  Widget _buildHeader() {
    String title = "ANTASENA PERFORMANCE";
    String subtitle = "ENGINE MONITORING SYSTEM v1.0";

    switch (_selectedStyle) {
      case 0: // Stealth Carbon
        return Row(
          children: [
            Container(width: 4, height: 40, color: const Color(0xFFFFD700)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.exo2(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                Text("HIGH-PERFORMANCE UNIT", style: GoogleFonts.exo2(color: const Color(0xFFFFD700), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ],
            ),
          ],
        );
      case 1: // Minimalist Glass
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w200, letterSpacing: -1)),
            Text(subtitle, style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        );
      case 2: // Retro Arcade
        return Column(
          children: [
            Text(title, style: GoogleFonts.pressStart2p(color: const Color(0xFFFF00FF), fontSize: 12)),
            const SizedBox(height: 8),
            Text("INSERT COIN TO START", style: GoogleFonts.pressStart2p(color: const Color(0xFF00FFFF), fontSize: 8)),
          ],
        );
      case 3: // Classic Analog
        return Column(
          children: [
            Text(title, style: GoogleFonts.libreBaskerville(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text("ESTABLISHED 2024", style: GoogleFonts.libreBaskerville(color: Colors.white.withOpacity(0.3), fontSize: 8, fontStyle: FontStyle.italic)),
          ],
        );
      default: return Container();
    }
  }

  Widget _buildMainGauge() {
    switch (_selectedStyle) {
      case 0: // Stealth Carbon
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("124", style: GoogleFonts.exo2(color: Colors.white, fontSize: 110, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, height: 1)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15, left: 5),
                  child: Text("KM/H", style: GoogleFonts.exo2(color: const Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Stack(
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("0 RPM", style: GoogleFonts.exo2(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold)),
                Text("8,420 RPM", style: GoogleFonts.exo2(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                Text("14,000", style: GoogleFonts.exo2(color: Colors.red.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        );
      case 1: // Minimalist Glass
        return Center(
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("124", style: GoogleFonts.inter(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w100)),
                Text("KM/H", style: GoogleFonts.inter(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4)),
                const SizedBox(height: 10),
                Text("8,420 RPM", style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 14)),
              ],
            ),
          ),
        );
      case 2: // Retro Arcade
        return Column(
          children: [
            Text("124", style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 60)),
            const SizedBox(height: 10),
            Text("KM/H", style: GoogleFonts.pressStart2p(color: const Color(0xFF00FFFF), fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFFFF00FF),
              child: Text("8420 RPM", style: GoogleFonts.pressStart2p(color: Colors.black, fontSize: 10)),
            ),
          ],
        );
      case 3: // Classic Analog
        return Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("124", style: GoogleFonts.libreBaskerville(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold)),
                    Text("KILOMETERS PER HOUR", style: GoogleFonts.libreBaskerville(color: Colors.white.withOpacity(0.3), fontSize: 8, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Text("8,420 RPM", style: GoogleFonts.libreBaskerville(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        );
      default: return Container();
    }
  }

  Widget _buildDataGrid() {
    List<Map<String, String>> data = [
      {"label": "0-100 KM/H", "value": "4.2s"},
      {"label": "200 METER", "value": "8.5s"},
      {"label": "400 METER", "value": "12.8s"},
      {"label": "GPS ACC", "value": "2.4m"},
    ];

    switch (_selectedStyle) {
      case 0: // Stealth Carbon
        return Column(
          children: data.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: Border(left: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.5), width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!, style: GoogleFonts.exo2(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                Text(item['value']!, style: GoogleFonts.exo2(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
              ],
            ),
          )).toList(),
        );
      case 1: // Minimalist Glass
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.8,
          children: data.map((item) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item['label']!, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(item['value']!, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
              ],
            ),
          )).toList(),
        );
      case 2: // Retro Arcade
        return Column(
          children: data.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00FFFF), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!, style: GoogleFonts.pressStart2p(color: const Color(0xFF00FFFF), fontSize: 8)),
                Text(item['value']!, style: GoogleFonts.pressStart2p(color: Colors.white, fontSize: 10)),
              ],
            ),
          )).toList(),
        );
      case 3: // Classic Analog
        return Column(
          children: data.map((item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!, style: GoogleFonts.libreBaskerville(color: Colors.white.withOpacity(0.4), fontSize: 10, fontStyle: FontStyle.italic)),
                Text(item['value']!, style: GoogleFonts.libreBaskerville(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        );
      default: return Container();
    }
  }

  Widget _buildActionButtons() {
    switch (_selectedStyle) {
      case 0: // Stealth Carbon
        return Column(
          children: [
            Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Center(
                child: Text("ENGAGE PERFORMANCE MODE", 
                  style: GoogleFonts.exo2(color: const Color(0xFFFFD700), fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: 1)
                ),
              ),
            ),
          ],
        );
      case 1: // Minimalist Glass
        return Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.cyanAccent,
            borderRadius: BorderRadius.circular(27),
          ),
          child: Center(
            child: Text("BEGIN SESSION", style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        );
      case 2: // Retro Arcade
        return Container(
          width: double.infinity,
          height: 60,
          color: const Color(0xFFFFFF00),
          child: Center(
            child: Text("PRESS START", style: GoogleFonts.pressStart2p(color: Colors.black, fontSize: 14)),
          ),
        );
      case 3: // Classic Analog
        return Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Center(
            child: Text("INITIALIZE CALIBRATION", style: GoogleFonts.libreBaskerville(color: Colors.white, fontSize: 10, letterSpacing: 2)),
          ),
        );
      default: return Container();
    }
  }
}
