import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import 'glass_widgets.dart';

class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const AppearanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;
    final activeGold = themeService.goldAccent;

    return GlassContainer(
      isDark: isDark,
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 25),
          const Text('Personalize ZedPool', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),

          _buildSectionTitle('Comfort Mode', activeGold),
          SwitchListTile(
            title: const Text('Dark Theme'),
            secondary: Icon(isDark ? Icons.nightlight_round : Icons.wb_sunny, color: activeGold),
            value: isDark,
            activeColor: activeGold,
            onChanged: (val) => themeService.toggleTheme(),
          ),

          const SizedBox(height: 20),
          _buildSectionTitle('Theme Color', activeGold),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: AppTheme.values.length,
              itemBuilder: (context, index) {
                final theme = AppTheme.values[index];
                final color = ThemeService.getThemeColor(theme);
                final isSelected = themeService.appTheme == theme;

                return GestureDetector(
                  onTap: () => themeService.setAppTheme(theme),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected) BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)
                          ],
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 30),
          _buildSectionTitle('Text & Display', activeGold),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.format_size, size: 16, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: themeService.fontSizeFactor,
                  min: 0.8, max: 1.4,
                  divisions: 6,
                  activeColor: activeGold,
                  onChanged: (val) => themeService.setFontSizeFactor(val),
                ),
              ),
              const Icon(Icons.format_size, size: 24, color: Colors.grey),
            ],
          ),

          const SizedBox(height: 20),
          _buildSectionTitle('Font Style', activeGold),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: ['Montserrat', 'Roboto', 'Lato', 'OpenSans'].map((font) {
              final isSelected = themeService.fontFamily == font;
              return ChoiceChip(
                label: Text(font, style: TextStyle(fontFamily: font)),
                selected: isSelected,
                onSelected: (val) => themeService.setFontFamily(font),
                selectedColor: activeGold.withOpacity(0.2),
                checkmarkColor: activeGold,
                labelStyle: TextStyle(color: isSelected ? activeGold : Colors.grey),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color gold) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }
}
