import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesignShowcasePage extends StatefulWidget {
  const DesignShowcasePage({super.key});

  @override
  State<DesignShowcasePage> createState() => _DesignShowcasePageState();
}

class _DesignShowcasePageState extends State<DesignShowcasePage> {
  int _selectedStyle = 0; // 0: Hardware, 1: Technical, 2: Brutalist

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
              const PopupMenuItem(value: 0, child: Text('Hardware Style')),
              const PopupMenuItem(value: 1, child: Text('Technical Style')),
              const PopupMenuItem(value: 2, child: Text('Brutalist Style')),
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
      case 0: return const Color(0xFF0A0A0A);
      case 1: return const Color(0xFFF0F0F0);
      case 2: return Colors.white;
      default: return Colors.black;
    }
  }

  Widget _buildHeader() {
    String title = "ANTASENA PERFORMANCE";
    String subtitle = "ENGINE MONITORING SYSTEM v1.0";

    switch (_selectedStyle) {
      case 0: // Hardware
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 1)),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
          ],
        );
      case 1: // Technical
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.inter(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)),
            Text(subtitle, style: GoogleFonts.libreBaskerville(color: Colors.black.withOpacity(0.5), fontSize: 10, fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            Container(height: 2, color: Colors.black),
          ],
        );
      case 2: // Brutalist
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.black,
              child: Text(title, style: GoogleFonts.anton(color: const Color(0xFF00FF00), fontSize: 28, letterSpacing: 1)),
            ),
            const SizedBox(height: 8),
            Text(subtitle.toUpperCase(), style: GoogleFonts.inter(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        );
      default: return Container();
    }
  }

  Widget _buildMainGauge() {
    switch (_selectedStyle) {
      case 0: // Hardware
        return Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radial marks (simplified)
                ...List.generate(12, (index) => Transform.rotate(
                  angle: (index * 30) * 3.14159 / 180,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(width: 1, height: 10, color: Colors.white.withOpacity(0.2)),
                  ),
                )),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("RPM", style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                    Text("8420", style: GoogleFonts.jetBrainsMono(color: const Color(0xFF00FF00), fontSize: 48, fontWeight: FontWeight.bold, shadows: [
                      Shadow(color: const Color(0xFF00FF00).withOpacity(0.5), blurRadius: 10)
                    ])),
                    Text("PEAK: 11200", style: GoogleFonts.jetBrainsMono(color: Colors.red.withOpacity(0.6), fontSize: 10)),
                  ],
                )
              ],
            ),
          ),
        );
      case 1: // Technical
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ENGINE SPEED", style: GoogleFonts.libreBaskerville(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black.withOpacity(0.5))),
                  Text("8,420", style: GoogleFonts.inter(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2)),
                  Text("REVOLUTIONS PER MINUTE", style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              Container(
                width: 60,
                height: 100,
                color: Colors.black,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(height: 70, color: const Color(0xFFFFFF00)),
                  ],
                ),
              )
            ],
          ),
        );
      case 2: // Brutalist
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("8420", style: GoogleFonts.anton(fontSize: 120, height: 0.8, color: Colors.black)),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: const Color(0xFF00FF00),
                  child: Text("RPM", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Container(height: 20, color: Colors.black)),
              ],
            )
          ],
        );
      default: return Container();
    }
  }

  Widget _buildDataGrid() {
    List<Map<String, String>> data = [
      {"label": "SPEED", "value": "124 KM/H"},
      {"label": "TPS", "value": "85%"},
      {"label": "TEMP", "value": "82°C"},
      {"label": "GEAR", "value": "4"},
    ];

    switch (_selectedStyle) {
      case 0: // Hardware
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: data.map((item) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF151619),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item['label']!, style: GoogleFonts.jetBrainsMono(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                Text(item['value']!, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        );
      case 1: // Technical
        return Column(
          children: data.map((item) => Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['label']!, style: GoogleFonts.libreBaskerville(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.black.withOpacity(0.5))),
                Text(item['value']!, style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        );
      case 2: // Brutalist
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: data.map((item) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label']!, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12)),
                Text(item['value']!, style: GoogleFonts.anton(fontSize: 24)),
              ],
            ),
          )).toList(),
        );
      default: return Container();
    }
  }

  Widget _buildActionButtons() {
    switch (_selectedStyle) {
      case 0: // Hardware
        return Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Center(child: Text("STOP ENGINE", style: GoogleFonts.jetBrainsMono(color: Colors.red, fontWeight: FontWeight.bold))),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF151619),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Icon(Icons.settings, color: Colors.white),
            )
          ],
        );
      case 1: // Technical
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Text("CONFIGURE SYSTEM", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      case 2: // Brutalist
        return Column(
          children: [
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF00FF00),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(4, 4))],
              ),
              child: Center(child: Text("START TUNING", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18))),
            ),
          ],
        );
      default: return Container();
    }
  }
}
