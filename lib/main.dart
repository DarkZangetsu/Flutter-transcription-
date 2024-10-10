import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:archive/archive.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Transcription de Réunions',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TranscriptionPage(),
    );
  }
}

class TranscriptionPage extends StatefulWidget {
  @override
  _TranscriptionPageState createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  final _audioRecorder = AudioRecorder();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _timer;
  List<String> _recordings = [];
  String _transcription = '';
  final translator = GoogleTranslator();
  TextEditingController _subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadRecordings();
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('L\'autorisation du microphone est nécessaire')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String path = await _getPath();
        await _audioRecorder.start(RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _startTimer();
      }
    } catch (e) {
      print('Erreur lors du démarrage de l\'enregistrement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors du démarrage de l\'enregistrement')),
      );
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      String? path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (path != null) {
        _recordings.add(path);
        await _saveRecordings();
      }
    } catch (e) {
      print('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'arrêt de l\'enregistrement')),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  Future<String> _getPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> _loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recordings = prefs.getStringList('recordings') ?? [];
    });
  }

  Future<void> _saveRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recordings', _recordings);
  }

  Future<void> _transcribeRecording(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        // Cette partie est simplifiée et nécessiterait une implémentation plus complexe
        // pour réellement transcrire un fichier audio enregistré
        bool available = await _speech.initialize();
        if (available) {
          setState(() {
            _transcription = "Transcription en cours...";
          });
          // Simulons une transcription pour cet exemple
          await Future.delayed(Duration(seconds: 2));
          setState(() {
            _transcription =
                "Ceci est une transcription simulée de l'enregistrement.";
          });
          // Traduire en français
          var translation =
              await translator.translate(_transcription, to: 'fr');
          setState(() {
            _transcription = translation.text;
          });
        }
      } catch (e) {
        print('Erreur lors de la transcription: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la transcription')),
        );
      }
    }
  }

  Future<void> _exportToDoc() async {
    if (_transcription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aucune transcription à exporter')),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final date = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final subject = _subjectController.text.isEmpty
          ? 'sans_sujet'
          : _subjectController.text;
      final fileName = '${date}_${subject.replaceAll(' ', '_')}.docx';
      final filePath = '${directory.path}/$fileName';

      await _saveAsDocx(_transcription, filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document exporté avec succès')),
      );
    } catch (e) {
      print('Erreur lors de l\'exportation en DOC: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'exportation en DOC')),
      );
    }
  }

  Future<void> _saveAsDocx(String content, String filePath) async {
    final archive = Archive();

    archive.addFile(ArchiveFile('word/document.xml', content.length, '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r>
        <w:t>${content.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>
'''));

    archive.addFile(ArchiveFile('_rels/.rels', 0, '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
'''));

    archive.addFile(ArchiveFile('[Content_Types].xml', 0, '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>
'''));

    final bytes = ZipEncoder().encode(archive);
    if (bytes != null) {
      final file = File(filePath);
      await file.writeAsBytes(bytes);
    } else {
      throw Exception('Failed to create DOCX file');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Transcription de Réunions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Sujet de la réunion',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Text('Durée: ${_recordDuration}s', style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording
                  ? 'Arrêter l\'enregistrement'
                  : 'Commencer l\'enregistrement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _recordings.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('Enregistrement ${index + 1}'),
                    onTap: () => _transcribeRecording(_recordings[index]),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Text('Transcription:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_transcription),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _exportToDoc,
              child: Text('Exporter en DOC'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
