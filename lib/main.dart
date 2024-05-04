import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Activity Tracker',
      home: ActivityTracker(),
    );
  }
}

class ActivityTracker extends StatefulWidget {
  const ActivityTracker({super.key});

  @override
  _ActivityTrackerState createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends State<ActivityTracker> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  final Map<DateTime, List<String>> _events = {};
  final TextEditingController _activityController = TextEditingController();
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _loadEvents();
    _loadTheme();
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _events.clear();
      for (final key in prefs.getKeys()) {
        final date = DateTime.parse(key);
        final List<String> activities = prefs.getStringList(key) ?? [];
        _events[date] = activities;
      }
    });
  }

  Future<void> _saveEvent(DateTime date, String activity) async {
    final prefs = await SharedPreferences.getInstance();
    final key = DateFormat('yyyy-MM-dd').format(date);
    final List<String> activities = prefs.getStringList(key) ?? [];
    activities.add(activity);
    await prefs.setStringList(key, activities);
    await _loadEvents(); // Reload events to update the UI
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> _saveTheme(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Activity Tracker',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Activity Tracker'),
          actions: [
            Switch(
              value: _isDarkMode,
              onChanged: (value) {
                _saveTheme(value);
              },
            ),
          ],
        ),
        body: Column(
          children: [
            TableCalendar(
              weekendDays: const [DateTime.friday, DateTime.saturday],
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.black),
                weekendStyle: TextStyle(color: Colors.red),
              ),
              calendarFormat: _calendarFormat,
              focusedDay: _focusedDay,
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.red),
                outsideDaysVisible: false, // Hide outside days
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
              ),
              availableCalendarFormats: const {
                CalendarFormat.month: 'Month',
                CalendarFormat.week: 'Week',
              },
              availableGestures: AvailableGestures.none,
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: (day) => _events[day] ?? [],
              onDaySelected: (selectedDay, focusedDay) {
                showDialog(
                  context: context,
                  builder: (context) => Theme(
                    data: Theme.of(context).copyWith(
                      dialogBackgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: AlertDialog(
                      title: const Text('Add Activity'),
                      content: TextField(
                        controller: _activityController,
                        decoration:
                            const InputDecoration(labelText: 'Activity'),
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            _saveEvent(selectedDay, _activityController.text);
                            _activityController.clear();
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(
              height: 16.0,
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'Events:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No events found'),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _events.entries.length,
                itemBuilder: (context, index) {
                  final sortedEntries = _events.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key));
                  final entry = sortedEntries[index];
                  return Dismissible(
                    key: Key(entry.key.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      _deleteEvent(entry.key);
                    },
                    child: ListTile(
                      title: Text(DateFormat.yMd().format(entry.key)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entry.value.map((activity) {
                          return Text(activity);
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEvent(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = DateFormat('yyyy-MM-dd').format(date);
    await prefs.remove(key);
    await _loadEvents(); // Reload events to update the UI
  }
}
