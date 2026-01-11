import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAHK0vKYHpRPbYDtz2eBk7p6wZSTkUC9PI",
      appId: "1:469293573030:web:c75e33ebab51a67e1ee567",
      messagingSenderId: "469293573030",
      projectId: "radiology-app-d8940",
      storageBucket: "radiology-app-d8940.firebasestorage.app",
    ),
  );
  runApp(const RadiologyApp());
}

class RadiologyApp extends StatelessWidget {
  const RadiologyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const BoardScreen(),
    );
  }
}

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});
  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final TextEditingController _controller = TextEditingController();
  final CollectionReference _posts = FirebaseFirestore.instance.collection('posts');
  String _selectedCategory = 'CT';
  XFile? _pickedFile; 

  // 이미지 선택 함수
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() { _pickedFile = image; });
    }
  }

  // 글 + 이미지 업로드 함수
  void _addPost() async {
    String? imageUrl;

    if (_pickedFile != null) {
      try {
        final String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final ref = FirebaseStorage.instance.ref().child('post_images/$fileName.jpg');
        await ref.putData(await _pickedFile!.readAsBytes());
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        print("이미지 업로드 에러: $e");
      }
    }

    if (_controller.text.isNotEmpty || imageUrl != null) {
      await _posts.add({
        'category': _selectedCategory,
        'content': _controller.text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _controller.clear();
      setState(() { _pickedFile = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('방사선과 이미지 게시판', style: TextStyle(color: Colors.white)),
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedCategory = ['CT', 'MR', 'X-ray'][index]),
            tabs: const [Tab(text: 'CT'), Tab(text: 'MR'), Tab(text: 'X-ray')],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder(
                stream: _posts.where('category', isEqualTo: _selectedCategory).orderBy('timestamp', descending: true).snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            if (data['imageUrl'] != null) Image.network(data['imageUrl'], height: 250, fit: BoxFit.cover),
                            ListTile(
                              title: Text(data['content'] ?? ''),
                              subtitle: Text(data['timestamp'] != null 
                                ? DateFormat('yyyy-MM-dd HH:mm').format(data['timestamp'].toDate()) 
                                : '방금 전'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            if (_pickedFile != null) 
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(8),
                child: Text('✅ 이미지 선택 완료: ${_pickedFile!.name}', style: const TextStyle(color: Colors.blue)),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.add_a_photo), onPressed: _pickImage), // 카메라 아이콘
                  Expanded(
                    child: TextField(
                      controller: _controller, 
                      decoration: const InputDecoration(hintText: '내용 입력...') // 힌트 문구 변경 확인용
                    )
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _addPost),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}