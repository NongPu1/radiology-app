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
      title: 'Seoul medical center',
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
  final CollectionReference _posts = FirebaseFirestore.instance.collection(
    'posts',
  );
  final Map<String, TextEditingController> _commentControllers = {};

  String _selectedCategory = 'CT';
  XFile? _pickedFile;
  String _currentUserName = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLoginDialog());
  }

  void _showLoginDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('사용자 이름 입력'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '이름을 입력하세요 (예: 이성택)'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _currentUserName = nameController.text.trim();
                });
                Navigator.pop(context);
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _addPost() async {
    String? imageUrl;
    setState(() {
      _isLoading = true;
    });
    try {
      if (_pickedFile != null) {
        final String fileName = DateTime.now().millisecondsSinceEpoch
            .toString();
        final ref = FirebaseStorage.instance.ref().child(
          'post_images/$fileName.jpg',
        );
        await ref.putData(await _pickedFile!.readAsBytes());
        imageUrl = await ref.getDownloadURL();
      }
      if (_controller.text.isNotEmpty || imageUrl != null) {
        await _posts.add({
          'category': _selectedCategory,
          'content': _controller.text,
          'imageUrl': imageUrl,
          'userName': _currentUserName,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _controller.clear();
        setState(() {
          _pickedFile = null;
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addComment(String postId, String text) async {
    if (text.trim().isEmpty) return;
    await _posts.doc(postId).collection('comments').add({
      'content': text,
      'userName': _currentUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _commentControllers[postId]?.clear();
  }

  Future<void> _deletePost(String docId, String? imageUrl) async {
    try {
      if (imageUrl != null) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }
      await _posts.doc(docId).delete();
    } catch (e) {
      print("삭제 오류: $e");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedFile = image;
      });
    }
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text(
            'Seoul Medical Center',
            style: TextStyle(color: Colors.white),
          ),
          bottom: TabBar(
            onTap: (index) => setState(
              () => _selectedCategory = ['CT', 'MR', 'X-ray'][index],
            ),
            tabs: const [
              Tab(text: 'CT'),
              Tab(text: 'MR'),
              Tab(text: 'X-ray'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder(
                stream: _posts
                    .where('category', isEqualTo: _selectedCategory)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  return ListView(
                    children: snapshot.data!.docs.map((doc) {
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;
                      _commentControllers.putIfAbsent(
                        doc.id,
                        () => TextEditingController(),
                      );
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            if (data['imageUrl'] != null)
                              GestureDetector(
                                onTap: () => _showFullImage(data['imageUrl']),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: data['userName'] == _currentUserName
                                        ? Border.all(
                                            color: Colors.yellow,
                                            width: 5,
                                          )
                                        : null,
                                  ),
                                  child: Image.network(
                                    data['imageUrl'],
                                    height: 250,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ListTile(
                              title: Text(data['content'] ?? ''),
                              subtitle: Text(
                                '${data['userName'] ?? '익명'} · ${data['timestamp'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(data['timestamp'].toDate()) : '방금 전'}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _deletePost(doc.id, data['imageUrl']),
                              ),
                            ),
                            // 댓글 목록 표시 영역
                            StreamBuilder(
                              stream: _posts
                                  .doc(doc.id)
                                  .collection('comments')
                                  .orderBy('timestamp', descending: false)
                                  .snapshots(),
                              builder:
                                  (
                                    context,
                                    AsyncSnapshot<QuerySnapshot> cSnapshot,
                                  ) {
                                    if (!cSnapshot.hasData)
                                      return const SizedBox();
                                    return Column(
                                      children: cSnapshot.data!.docs.map((
                                        cDoc,
                                      ) {
                                        Map<String, dynamic> cData =
                                            cDoc.data() as Map<String, dynamic>;
                                        return ListTile(
                                          dense: true,
                                          title: Text(cData['content'] ?? ''),
                                          subtitle: Text(
                                            cData['userName'] ?? '익명',
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                            ),
                            // 댓글 입력창
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _commentControllers[doc.id],
                                      decoration: const InputDecoration(
                                        hintText: '댓글 입력...',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () => _addComment(
                                      doc.id,
                                      _commentControllers[doc.id]!.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: '내용을 입력하세요'),
                    ),
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
