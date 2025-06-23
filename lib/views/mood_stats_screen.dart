import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import '../models/journal_entry.dart';

class MoodStatsScreen extends StatelessWidget {
  final List<JournalEntry> entries;

  const MoodStatsScreen({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final moodData = _prepareChartData();

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Trends')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: charts.BarChart(
                moodData,
                animate: true,
                domainAxis: const charts.OrdinalAxisSpec(
                  renderSpec: charts.SmallTickRendererSpec(
                    labelRotation: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Your mood over time'),
          ],
        ),
      ),
    );
  }

  List<charts.Series<MoodData, String>> _prepareChartData() {
    final moodCounts = <String, int>{};
    
    for (var entry in entries) {
      moodCounts.update(entry.mood, (value) => value + 1, ifAbsent: () => 1);
    }

    final data = moodCounts.entries
        .map((e) => MoodData(e.key, e.value))
        .toList();

    return [
      charts.Series<MoodData, String>(
        id: 'Moods',
        colorFn: (_, idx) => charts.MaterialPalette.blue.makeShades(5)[idx!],
        domainFn: (MoodData mood, _) => mood.mood,
        measureFn: (MoodData mood, _) => mood.count,
        data: data,
      )
    ];
  }
}

class MoodData {
  final String mood;
  final int count;

  MoodData(this.mood, this.count);
}