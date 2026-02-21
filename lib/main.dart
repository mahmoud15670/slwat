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
  List<String> fullPageText = [];
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

        if (data is Map<String, dynamic> && data['pages'] != null) {
          // Create a list of verse texts
          List<String> verses = [];
          for (var verse in data['pages']) {
            verses.add(_getVerseWithCircle(
                verse['verse'], verse['text'])); // Add each verse's text
          }

          final pageData = {
            'fullPage': verses, // Store list of verse texts
            'start': data['pages'][0]['text'], // النص الذي يبدأ به الصفحة
            'end': data['pages'].last['text'], // النص الذي تنتهي به الصفحة
          };

          await quranBox.put(page, pageData); // Save data to Hive
          _updateUI(pageData); // Update UI
        } else {
          _showError('البيانات المستلمة ليست بتنسيق صحيح.');
        }
      } else {
        _showError('تعذر تحميل الصفحة. حالة: ${response.statusCode}');
      }
    } catch (e) {
      _showError('حدث خطأ في الاتصال: $e');
    }
  }

  String _getVerseWithCircle(int verseNumber, String verseText) {
    // Create the verse text with the verse number inside the circle
    return ' [$verseNumber] ' +
        verseText; // Store just the text, including verse number
  }

  void _updateUI(Map data) {
    setState(() {
      fullPageText =
          List<String>.from(data['fullPage']); // Store verses as text
      startText = data['start']; // Start text
      endText = data['end']; // End text
    });

    settingsBox.put('lastPage', pageNumber); // Save the page number in settings
  }

  void _showError(String message) {
    setState(() {
      hasError = true;
      startText = message;
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
    return text.length <= length ? text : text.substring(0, length);
  }

  void _showFullPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('صفحة $pageNumber كاملة'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: fullPageText.map((verseText) {
                  return Text(
                    verseText,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.right, // Right-align text for Arabic
                  );
                }).toList(), // Convert the list of texts into a list of Text widgets
              ),
            ),
          ),
        ),
      ),
    );
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
                      style: TextStyle(fontSize: 18.0),
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
                      style: TextStyle(fontSize: 18.0),
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
          children: [
            Text('صفحة $pageNumber'),
            IconButton(
              color: Theme.of(context).primaryColorLight,
              onPressed: _showFullPage,
              icon: const Icon(Icons.remove_red_eye),
            ),
          ],
        ),
      ),
    );
  }
}
