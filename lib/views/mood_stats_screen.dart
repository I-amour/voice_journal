import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/journal_entry.dart';
import 'package:intl/intl.dart';

class MoodStatsScreen extends StatelessWidget {
  final List<JournalEntry> entries;
  final Color primaryColor;
  final Color accentColor;
  final Color textPrimaryColor;
  final Color textSecondaryColor;

  const MoodStatsScreen({
    super.key, 
    required this.entries,
    required this.primaryColor,
    required this.accentColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: Text(
            'Mood Analytics',
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryColor),
        ),
        body: Center(
          child: Text(
            'No entries available for analysis',
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    final moodData = _preparePieChartData();
    final weeklyTrends = _prepareLineChartData();
    final mostCommonMood = _getMostCommonMood();
    final longestStreak = _calculateLongestStreak();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          'Mood Analytics',
          style: TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            _buildOverviewCards(mostCommonMood, longestStreak),
            
            const SizedBox(height: 24),
            
            // Mood Distribution Chart
            _buildSectionTitle('Mood Distribution'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                height: 300,
                child: PieChart(
                  PieChartData(
                    sections: moodData,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Weekly Trends
            if (weeklyTrends['lineBarsData'] != null && 
                (weeklyTrends['lineBarsData'] as List<LineChartBarData>).isNotEmpty) ...[
              _buildSectionTitle('Weekly Trends'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 250,
                      child: LineChart(
                        LineChartData(
                          lineTouchData:  LineTouchData(enabled: true),
                          gridData:  FlGridData(show: true),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                                  return Text(
                                    DateFormat('MMM d').format(date),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                                reservedSize: 30,
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: true),
                          minX: weeklyTrends['minX'] as double,
                          maxX: weeklyTrends['maxX'] as double,
                          minY: 0,
                          maxY: weeklyTrends['maxY'] as double,
                          lineBarsData: weeklyTrends['lineBarsData'] as List<LineChartBarData>,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMoodLegend(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Recent Mood Entries
            _buildSectionTitle('Recent Entries'),
            const SizedBox(height: 12),
            ..._buildRecentEntriesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: textPrimaryColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildOverviewCards(String mostCommonMood, int longestStreak) {
    final totalEntries = entries.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Entries',
            value: totalEntries.toString(),
            icon: Icons.book_rounded,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Most Common Mood',
            value: mostCommonMood.capitalize(),
            icon: _getMoodIcon(mostCommonMood),
            color: _getMoodColor(mostCommonMood),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Longest Streak',
            value: '$longestStreak days',
            icon: Icons.trending_up_rounded,
            color: accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textSecondaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Positive', _getMoodColor('positive')),
        const SizedBox(width: 16),
        _buildLegendItem('Negative', _getMoodColor('negative')),
        const SizedBox(width: 16),
        _buildLegendItem('Neutral', _getMoodColor('neutral')),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: textSecondaryColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildRecentEntriesList() {
    final recentEntries = entries.take(3).toList();
    
    if (recentEntries.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              'No recent entries',
              style: TextStyle(color: textSecondaryColor),
            ),
          ),
        ),
      ];
    }

    return recentEntries.map((entry) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getMoodColor(entry.mood).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getMoodIcon(entry.mood),
                    color: _getMoodColor(entry.mood),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.mood.capitalize(),
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d').format(entry.date),
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimaryColor.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Data preparation methods
  List<PieChartSectionData> _preparePieChartData() {
    final moodCounts = <String, int>{};
    
    for (var entry in entries) {
      moodCounts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
    }

    final total = moodCounts.values.fold(0, (sum, count) => sum + count);
    if (total == 0) return [];

    return moodCounts.entries.map((entry) {
      final mood = entry.key;
      final count = entry.value;
      final percentage = (count / total * 100).round();

      return PieChartSectionData(
        color: _getMoodColor(mood),
        value: count.toDouble(),
        title: '$percentage%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Map<String, dynamic> _prepareLineChartData() {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));
    
    // Filter entries from the last month
    final recentEntries = entries.where((entry) => entry.date.isAfter(oneMonthAgo)).toList();
    
    if (recentEntries.isEmpty) {
      return {
        'minX': 0.0,
        'maxX': 1.0,
        'maxY': 1.0,
        'lineBarsData': <LineChartBarData>[],
      };
    }
    
    // Group entries by week
    final weeklyGroups = <DateTime, Map<String, int>>{};
    
    for (var entry in recentEntries) {
      final weekStart = _getWeekStart(entry.date);
      weeklyGroups.putIfAbsent(weekStart, () => {'positive': 0, 'negative': 0, 'neutral': 0});
      weeklyGroups[weekStart]![entry.mood] = (weeklyGroups[weekStart]![entry.mood] ?? 0) + 1;
    }

    if (weeklyGroups.isEmpty) {
      return {
        'minX': 0.0,
        'maxX': 1.0,
        'maxY': 1.0,
        'lineBarsData': <LineChartBarData>[],
      };
    }

    // Prepare line chart data
    final spotsPositive = <FlSpot>[];
    final spotsNegative = <FlSpot>[];
    final spotsNeutral = <FlSpot>[];

    final sortedWeeks = weeklyGroups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    for (var entry in sortedWeeks) {
      final x = entry.key.millisecondsSinceEpoch.toDouble();
      spotsPositive.add(FlSpot(x, (entry.value['positive'] ?? 0).toDouble()));
      spotsNegative.add(FlSpot(x, (entry.value['negative'] ?? 0).toDouble()));
      spotsNeutral.add(FlSpot(x, (entry.value['neutral'] ?? 0).toDouble()));
    }

    final minX = sortedWeeks.first.key.millisecondsSinceEpoch.toDouble();
    final maxX = sortedWeeks.last.key.millisecondsSinceEpoch.toDouble();
    final maxY = weeklyGroups.values
        .map((map) => map.values.reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return {
      'minX': minX,
      'maxX': maxX,
      'maxY': maxY + 1, // Add padding
      'lineBarsData': <LineChartBarData>[
        LineChartBarData(
          spots: spotsPositive,
          isCurved: true,
          color: _getMoodColor('positive'),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData:  FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: spotsNegative,
          isCurved: true,
          color: _getMoodColor('negative'),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
        LineChartBarData(
          spots: spotsNeutral,
          isCurved: true,
          color: _getMoodColor('neutral'),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    };
  }

  String _getMostCommonMood() {
    if (entries.isEmpty) return 'neutral';
    
    final moodCounts = <String, int>{};
    for (var entry in entries) {
      moodCounts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
    }
    return moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int _calculateLongestStreak() {
    if (entries.isEmpty) return 0;
    
    final sortedEntries = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));
    
    int currentStreak = 1;
    int longestStreak = 1;
    
    for (int i = 1; i < sortedEntries.length; i++) {
      final previousDate = sortedEntries[i-1].date;
      final currentDate = sortedEntries[i].date;
      
      if (currentDate.difference(previousDate).inDays == 1) {
        currentStreak++;
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
    }
    
    return longestStreak;
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Color _getMoodColor(String mood) {
    switch (mood.toLowerCase()) {
      case 'positive':
        return const Color(0xFF68D391);
      case 'negative':
        return const Color(0xFFFC8181);
      default:
        return const Color(0xFFECC94B);
    }
  }

  IconData _getMoodIcon(String mood) {
    switch (mood.toLowerCase()) {
      case 'positive':
        return Icons.sentiment_very_satisfied_rounded;
      case 'negative':
        return Icons.sentiment_very_dissatisfied_rounded;
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }
}

// Helper extensions
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

// Data classes (if not already defined elsewhere)
class MoodData {
  final String mood;
  final int count;

  MoodData(this.mood, this.count);
}

class WeeklyTrendData {
  final DateTime weekStart;
  final int count;

  WeeklyTrendData(this.weekStart, this.count);
}