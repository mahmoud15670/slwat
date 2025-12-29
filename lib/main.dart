import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  await Hive.openBox('quran');

  await Hive.openBox('settings');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String title = 'التلاوة في الصلاة';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
      ),
      title: title,
      home: const QuranPage(),
    );
  }
}

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  final quranBox = Hive.box('quran');

  final settingsBox = Hive.box('settings');

  int pageNumber = 1;

  String startText = '';

  String endText = '';

  bool isLoading = false;

  bool hasError = false;

  @override
  void initState() {
    super.initState();

    pageNumber = settingsBox.get('lastPage', defaultValue: 1);

    _loadPage(pageNumber);
  }

  Future<void> _loadPage(int page) async {
    setState(() {
      isLoading = true;

      hasError = false;
    });

    final saved = quranBox.get(page);

    if (saved != null) {
      _updateUI(saved);
    } else {
      await _downloadPage(page);
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _downloadPage(int page) async {
    final url = Uri.parse(
      'https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions/ara-quranbazzi/pages/$page.json',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final pageData = {
          'start': data['pages'][0]['text'],
          'end': data['pages'].last['text'],
        };

        await quranBox.put(page, pageData);

        _updateUI(pageData);
      } else {
        _showError(response.statusCode);
      }
    } catch (e) {
      _showError(e);
    }
  }

  void _updateUI(Map data) {
    setState(() {
      startText = data['start'];

      endText = data['end'];
    });

    settingsBox.put('lastPage', pageNumber);
  }

  void _showError(code) {
    setState(() {
      hasError = true;

      startText = '$code تعذر تحميل الصفحة حاليًا';

      endText = 'يرجى المحاولة مرة أخرى';
    });
  }

  void _nextPage() {
    pageNumber = pageNumber == 50 ? 1 : pageNumber + 1;

    _loadPage(pageNumber);
  }

  void _prevPage() {
    if (pageNumber > 1) {
      pageNumber--;

      _loadPage(pageNumber);
    }
  }

  String safeSubstring(String text, int length) {
    if (text.length <= length) return text;
    return text.substring(0, length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      appBar: AppBar(title: const Text(MyApp.title)),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'بسم الله الرحمن الرحيم',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                      ),
                    ),
                    const SizedBox(height: 50),
                    const Text(
                      'تبدأ الصفحة بقوله تعالى:',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '...' + safeSubstring(startText, 60),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 25),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'تنتهي الصفحة بقوله تعالى:',
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '...' + safeSubstring(endText, 60),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 25),
                    ),
                    if (hasError) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _loadPage(pageNumber),
                        child: const Text('إعادة المحاولة'),
                      )
                    ]
                  ],
                ),
              ),
      ),
      bottomSheet: ListTile(
        textColor: Theme.of(context).primaryColorLight,
        horizontalTitleGap: 20.0,
        titleTextStyle: const TextStyle(fontSize: 30.0),
        tileColor: Theme.of(context).primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: IconButton(
          onPressed: _nextPage,
          icon: const Icon(Icons.add),
          color: Theme.of(context).primaryColorLight,
        ),
        trailing: IconButton(
          onPressed: _prevPage,
          icon: const Icon(Icons.remove),
          color: Theme.of(context).primaryColorLight,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text('صفحة $pageNumber')],
        ),
      ),
    );
  }
}
