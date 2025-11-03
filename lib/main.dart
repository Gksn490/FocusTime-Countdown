import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(FocusTimeApp());
}

class FocusTimeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusTime',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.black,
        cardColor: Colors.deepPurple[900],
      ),
      home: CountdownHomePage(),
    );
  }
}

class Countdown {
  String title;
  DateTime targetDate;
  String? note;
  String? emoji;

  Countdown({
    required this.title,
    required this.targetDate,
    this.note,
    this.emoji,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'note': note,
        'emoji': emoji,
      };

  static Countdown fromJson(Map<String, dynamic> json) => Countdown(
        title: json['title'] as String,
        targetDate: DateTime.parse(json['targetDate'] as String),
        note: json['note'] as String?,
        emoji: json['emoji'] as String?,
      );
}

class CountdownHomePage extends StatefulWidget {
  @override
  _CountdownHomePageState createState() => _CountdownHomePageState();
}

class _CountdownHomePageState extends State<CountdownHomePage> {
  List<Countdown> countdowns = [];

  @override
  void initState() {
    super.initState();
    _loadCountdowns();
  }

  Future<void> _loadCountdowns() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('countdowns');
    if (data != null) {
      List<dynamic> jsonList = jsonDecode(data);
      setState(() {
        countdowns =
            jsonList.map<Countdown>((dynamic item) => Countdown.fromJson(item as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _saveCountdowns() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = countdowns.map<Map<String, dynamic>>((Countdown e) => e.toJson()).toList();
    await prefs.setString('countdowns', jsonEncode(jsonList));
  }

  void _addCountdown(Countdown c) {
    setState(() {
      countdowns.add(c);
    });
    _saveCountdowns();
  }

  void _removeCountdown(int index) {
    setState(() {
      countdowns.removeAt(index);
    });
    _saveCountdowns();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FocusTime"),
        backgroundColor: Colors.deepPurpleAccent,
        centerTitle: true,
      ),
      body: countdowns.isEmpty
          ? const Center(child: Text("No countdowns yet!", style: TextStyle(fontSize: 18)))
          : ListView.builder(
              itemCount: countdowns.length,
              itemBuilder: (BuildContext context, int index) {
                final Countdown c = countdowns[index];
                return CountdownCard(
                  countdown: c,
                  onDelete: () => _removeCountdown(index),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add),
        onPressed: () async {
          final dynamic newCountdown = await Navigator.push(
            context,
            MaterialPageRoute<Countdown>(builder: (BuildContext context) => AddCountdownPage()),
          );
          if (newCountdown != null && newCountdown is Countdown) {
            _addCountdown(newCountdown);
          }
        },
      ),
    );
  }
}

class CountdownCard extends StatefulWidget {
  final Countdown countdown;
  final VoidCallback onDelete;

  const CountdownCard({
    super.key,
    required this.countdown,
    required this.onDelete,
  });

  @override
  _CountdownCardState createState() => _CountdownCardState();
}

class _CountdownCardState extends State<CountdownCard> {
  late Timer _timer;
  late String _timeLeft;

  @override
  void initState() {
    super.initState();
    _timeLeft = _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft = _calculateTimeLeft();
      });
    });
  }

  String _calculateTimeLeft() {
    final Duration diff = widget.countdown.targetDate.difference(DateTime.now());
    if (diff.isNegative) return "Done!";
    final int days = diff.inDays;
    final int hours = diff.inHours % 24;
    final int minutes = diff.inMinutes % 60;
    final int seconds = diff.inSeconds % 60;
    return "$days d $hours h $minutes m $seconds s";
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.deepPurpleAccent, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            "${widget.countdown.emoji ?? "⏳"} ${widget.countdown.title}",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.countdown.note != null && widget.countdown.note!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  widget.countdown.note!,
                  style: const TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _timeLeft,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: widget.onDelete,
          ),
        ),
      ),
    );
  }
}

class AddCountdownPage extends StatefulWidget {
  @override
  _AddCountdownPageState createState() => _AddCountdownPageState();
}

class _AddCountdownPageState extends State<AddCountdownPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime? _selectedDate;
  String? _emoji;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set a Goal"), // Changed from "Add Countdown"
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Title"),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: "Note (optional)"),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                ElevatedButton(
                  onPressed: _pickDate,
                  child: const Text("Pick Date"),
                ),
                const SizedBox(width: 10),
                Text(
                  _selectedDate == null
                      ? "No date selected"
                      : DateFormat.yMMMd().format(_selectedDate!),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    final String? pickedEmoji = await showDialog<String>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return const EmojiPickerDialog();
                      },
                    );
                    if (pickedEmoji != null) {
                      setState(() {
                        _emoji = pickedEmoji;
                      });
                    }
                  },
                  child: const Text("Pick Emoji"),
                ),
                const SizedBox(width: 10),
                Text(
                  _emoji == null || _emoji!.isEmpty ? "No emoji selected" : _emoji!,
                  style: const TextStyle(fontSize: 24),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (_titleController.text.isNotEmpty && _selectedDate != null) {
                  Navigator.pop(
                    context,
                    Countdown(
                      title: _titleController.text,
                      targetDate: _selectedDate!,
                      note: _noteController.text.isNotEmpty ? _noteController.text : null,
                      emoji: _emoji,
                    ),
                  );
                }
              },
              child: const Text("Save", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}

class EmojiPickerDialog extends StatelessWidget {
  const EmojiPickerDialog({super.key});

  static const List<String> _emojis = <String>[
    '😊', '👍', '🚀', '🎉', '🌟', '❤️', '🔥', '✅', '💡', '⏰',
    '🗓️', '📖', '💻', '💡', '🏆', '🎯', '👨‍💻', '📈', '🧘', '💰',
    '🏠', '🏖️', '✈️', '🍔', '☕', '🥳', '🎁', '🎂', '🎓', '💪'
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Pick an Emoji"),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 1,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _emojis.length,
          itemBuilder: (BuildContext context, int index) {
            final String emoji = _emojis[index];
            return InkWell(
              onTap: () {
                Navigator.of(context).pop(emoji);
              },
              child: Center(
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close without selecting
          },
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
