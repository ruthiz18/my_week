import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'holidays.dart';

void main() {
  runApp(const MyWeekApp());
}

const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

// ---------- Times (Lab 1) ----------

int? toMinutes(String text) {
  var parts = text.trim().split(':');
  if (parts.length != 2) return null;
  if (parts[1].length != 2) return null;
  var hours = int.tryParse(parts[0]);
  var mins = int.tryParse(parts[1]);
  if (hours == null || mins == null) return null;
  if (hours < 0 || hours > 23) return null;
  if (mins < 0 || mins > 59) return null;
  return hours * 60 + mins;
}

String clock(int minutes) {
  var h = minutes ~/ 60;
  var m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String niceTime(int minutes) {
  var hours = minutes ~/ 60;
  var mins = minutes % 60;
  return '${hours}h ${mins}m';
}

String? checkCourse(String name, String startText, String endText) {
  if (name.trim().isEmpty) {
    return 'Enter a course name.';
  }
  var start = toMinutes(startText);
  if (start == null) {
    return 'Start time must look like 08:00 (hours 00-23, minutes 00-59).';
  }
  var end = toMinutes(endText);
  if (end == null) {
    return 'End time must look like 10:30 (hours 00-23, minutes 00-59).';
  }
  if (end <= start) {
    return 'The end time must be after the start time.';
  }
  return null;
}

// ---------- Order (Lab 9) ----------

List<Map<String, dynamic>> sortByStart(List<Map<String, dynamic>> courses) {
  var copy = List<Map<String, dynamic>>.of(courses);
  var sorted = <Map<String, dynamic>>[];
  while (copy.isNotEmpty) {
    var earliest = copy[0];
    for (var c in copy) {
      if ((c['start'] as int) < (earliest['start'] as int)) {
        earliest = c;
      }
    }
    sorted.add(earliest);
    copy.remove(earliest);
  }
  return sorted;
}

List<Map<String, dynamic>> coursesOnDay(
  List<Map<String, dynamic>> courses,
  int day,
) {
  var result = <Map<String, dynamic>>[];
  for (var c in courses) {
    if (c['day'] == day) {
      result.add(c);
    }
  }
  return sortByStart(result);
}

// ---------- Clashes (Lab 7) ----------

bool clashes(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a['day'] != b['day']) return false;
  return (a['start'] as int) < (b['end'] as int) &&
      (b['start'] as int) < (a['end'] as int);
}

List<String> clashNames(
  Map<String, dynamic> course,
  List<Map<String, dynamic>> list,
) {
  var names = <String>[];
  for (var other in list) {
    if (identical(other, course)) continue;
    if (clashes(course, other)) {
      names.add(other['name'] as String);
    }
  }
  return names;
}

// ---------- Totals ----------

int totalMinutes(List<Map<String, dynamic>> list) {
  var total = 0;
  for (var c in list) {
    total += (c['end'] as int) - (c['start'] as int);
  }
  return total;
}

List<Map<String, dynamic>> makeSamples() {
  return [
    {'name': 'Mathematics', 'day': 0, 'start': 480, 'end': 600}, // 08:00-10:00
    {'name': 'Physics', 'day': 0, 'start': 600, 'end': 690}, // 10:00-11:30
    {'name': 'Physics', 'day': 1, 'start': 630, 'end': 720}, // 10:30-12:00
    {
      'name': 'Programming',
      'day': 1,
      'start': 540,
      'end': 660,
    }, // 09:00-11:00 (clash)
    {'name': 'Lab 1', 'day': 3, 'start': 840, 'end': 960}, // 14:00-16:00
    {'name': 'English', 'day': 4, 'start': 540, 'end': 600}, // 09:00-10:00
  ];
}

// ---------- App ----------

class MyWeekApp extends StatelessWidget {
  const MyWeekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Week',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const WeekPage(),
    );
  }
}

class WeekPage extends StatefulWidget {
  const WeekPage({super.key});

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  var courses = makeSamples();
  var selectedDay = 0;

  @override
  void initState() {
    super.initState();
    loadCourses();
  }

  // ---------- Saving (shared_preferences) ----------

  Future<void> saveCourses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('courses', jsonEncode(courses));
  }

  Future<void> loadCourses() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('courses');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      setState(() {
        courses = list.map((x) => Map<String, dynamic>.from(x as Map)).toList();
      });
    }
  }

  void openHolidays() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HolidaysPage(courses: courses)),
    );
  }

  bool dayHasClash(int day) {
    var list = coursesOnDay(courses, day);
    for (var c in list) {
      if (clashNames(c, list).isNotEmpty) return true;
    }
    return false;
  }

  Future<void> openEditor([Map<String, dynamic>? course]) async {
    var result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditPage(course: course, day: selectedDay),
      ),
    );
    if (result == null) return;

    setState(() {
      if (result['delete'] == true) {
        courses.remove(course);
      } else if (course == null) {
        courses.add(result);
        selectedDay = result['day'] as int;
      } else {
        var index = courses.indexOf(course);
        courses[index] = result;
        selectedDay = result['day'] as int;
      }
    });
    saveCourses();
  }

  Widget dayChip(int d) {
    var hasClash = dayHasClash(d);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ChoiceChip(
          showCheckmark: false,
          padding: EdgeInsets.zero,
          labelPadding: EdgeInsets.zero,
          label: Center(
            child: Text(
              dayShort[d],
              style: TextStyle(
                color: hasClash ? Colors.red.shade700 : null,
                fontWeight: hasClash ? FontWeight.bold : null,
              ),
            ),
          ),
          selected: selectedDay == d,
          onSelected: (value) {
            setState(() {
              selectedDay = d;
            });
          },
        ),
      ),
    );
  }

  Widget courseCard(
    Map<String, dynamic> course,
    List<Map<String, dynamic>> today,
  ) {
    var names = clashNames(course, today);
    var isClash = names.isNotEmpty;

    var start = course['start'] as int;
    var end = course['end'] as int;
    var times = '${clock(start)}-${clock(end)}  (${niceTime(end - start)})';
    var subtitle = isClash ? '$times\nClashes with ${names.join(', ')}' : times;

    return Card(
      color: isClash ? Colors.red.shade100 : null,
      child: ListTile(
        textColor: isClash ? Colors.red.shade900 : null,
        title: Text(
          course['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => openEditor(course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var today = coursesOnDay(courses, selectedDay);
    var dayTotal = totalMinutes(today);
    var weekTotal = totalMinutes(courses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_busy),
            tooltip: 'Public holidays',
            onPressed: openHolidays,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Week total: ${niceTime(weekTotal)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [for (var d = 0; d < 5; d++) dayChip(d)]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayNames[selectedDay],
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  niceTime(dayTotal),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: today.isEmpty
                ? Center(child: Text('No classes on ${dayNames[selectedDay]}'))
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [for (var c in today) courseCard(c, today)],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------- Add / edit screen ----------

class EditPage extends StatefulWidget {
  final Map<String, dynamic>? course; // null = adding a new course
  final int day; // default day when adding

  const EditPage({super.key, this.course, required this.day});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController nameCtrl;
  late TextEditingController startCtrl;
  late TextEditingController endCtrl;
  late int day;
  String? error;

  @override
  void initState() {
    super.initState();
    var c = widget.course;
    nameCtrl = TextEditingController(
      text: c == null ? '' : c['name'] as String,
    );
    startCtrl = TextEditingController(
      text: c == null ? '' : clock(c['start'] as int),
    );
    endCtrl = TextEditingController(
      text: c == null ? '' : clock(c['end'] as int),
    );
    day = c == null ? widget.day : c['day'] as int;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    super.dispose();
  }

  void save() {
    var problem = checkCourse(nameCtrl.text, startCtrl.text, endCtrl.text);
    if (problem != null) {
      setState(() {
        error = problem;
      });
      return;
    }
    Navigator.pop(context, {
      'name': nameCtrl.text.trim(),
      'day': day,
      'start': toMinutes(startCtrl.text)!,
      'end': toMinutes(endCtrl.text)!,
    });
  }

  Future<void> confirmDelete() async {
    var sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text('Delete ${widget.course!['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure == true && mounted) {
      Navigator.pop(context, {'delete': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    var editing = widget.course != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit course' : 'Add course'),
        actions: [
          if (editing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Course name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: day,
            decoration: const InputDecoration(
              labelText: 'Day',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var d = 0; d < 5; d++)
                DropdownMenuItem(value: d, child: Text(dayNames[d])),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  day = value;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: startCtrl,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Start time',
              hintText: '08:00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: endCtrl,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'End time',
              hintText: '10:30',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: save, child: const Text('Save')),
        ],
      ),
    );
  }
}
// ---------- Public holidays screen (API) ----------

const monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class HolidaysPage extends StatefulWidget {
  final List<Map<String, dynamic>> courses;

  const HolidaysPage({super.key, required this.courses});

  @override
  State<HolidaysPage> createState() => _HolidaysPageState();
}

class _HolidaysPageState extends State<HolidaysPage> {
  List<Holiday> holidays = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await fetchHolidays();
      setState(() {
        holidays = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Could not load the holidays. Check your internet connection.';
      });
    }
  }

  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    load();
  }

  Widget holidayTile(Holiday h) {
    var d = h.date;
    var dateText = '${d.day} ${monthShort[d.month - 1]} ${d.year}';
    // DateTime.weekday: Monday = 1 ... Sunday = 7. My Week days: Monday = 0.
    var day = d.weekday - 1;
    String info;
    var missed = 0;
    if (day < 5) {
      missed = coursesOnDay(widget.courses, day).length;
      info = missed == 0
          ? '${dayNames[day]}: no classes that day'
          : '${dayNames[day]}: $missed ${missed == 1 ? 'class' : 'classes'} off';
    } else {
      info = 'Weekend';
    }

    return Card(
      color: missed > 0 ? Colors.green.shade50 : null,
      child: ListTile(
        leading: const Icon(Icons.celebration),
        title: Text(
          h.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$dateText\n$info'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Public holidays in Rwanda')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48),
                    const SizedBox(height: 12),
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: retry, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [for (var h in holidays) holidayTile(h)],
              ),
            ),
    );
  }
}
