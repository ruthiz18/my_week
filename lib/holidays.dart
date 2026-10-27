import 'dart:convert';

import 'package:http/http.dart' as http;

class Holiday {
  Holiday({required this.date, required this.name});

  final DateTime date;
  final String name;

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      date: DateTime.parse(json['date'] as String),
      name: json['name'] as String,
    );
  }
}

// The next public holidays in Rwanda, from the free Nager.Date API.
Future<List<Holiday>> fetchHolidays() async {
  final url = Uri.parse('https://date.nager.at/api/v3/NextPublicHolidays/RW');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('The holidays server answered ${response.statusCode}');
  }
  final list = jsonDecode(response.body) as List;
  return list.map((x) => Holiday.fromJson(x as Map<String, dynamic>)).toList();
}
