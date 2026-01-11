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
      title: 'Seoul medical center', // 브라우저 탭에 표시될 이름
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
  String _selectedCategory = 'CT';
  XFile? _pickedFile;
  bool _isLoading = false;
  final TextEditingController _commentController = TextEditingController();
  // 49번 줄 바로 아래에 추가
  final Map<String, TextEditingController> _commentControllers = {};

  Future<void> _addComment(String postId) async {
    if (_commentController.text.isEmpty) return;
    await _posts.doc(postId).collection('comments').add({
      'content': _commentController.text,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _commentController.clear();
  }

  Future<void> _deletePost(String docId, String? imageUrl) async {
    try {
      // 1. 이미지가 있다면 저장소(Storage)에서 먼저 삭제합니다.
      if (imageUrl != null) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }
      // 2. 게시물 데이터를 삭제합니다.
      await _posts.doc(docId).delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('게시물이 삭제되었습니다.')));
      }
    } catch (e) {
      print("삭제 중 오류 발생: $e");
    }
  }

  // 44번 줄 바로 아래에 붙여넣으세요!
  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // 1. 이미지 전체를 클릭 감지기로 감쌉니다.
            GestureDetector(
              onTap: () => Navigator.pop(context), // 이미지 클릭 시 창 닫기
              child: InteractiveViewer(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            // 2. 기존 X 버튼도 그대로 유지 (사용자 편의성)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // 이미지 선택 함수
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedFile = image;
      });
    }
  }

  // 글 + 이미지 업로드 함수
  void _addPost() async {
    String? imageUrl;

    // 1. 업로드 시작! 로딩 상태를 켭니다.
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
          'timestamp': FieldValue.serverTimestamp(),
        });
        _controller.clear();
        setState(() {
          _pickedFile = null;
        });
      }
    } catch (e) {
      print("에러 발생: $e");
    } finally {
      // 2. 성공하든 실패하든 업로드가 끝나면 로딩 상태를 끕니다.
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text(
            'Seoul Medical Center 영상의학과',
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

                      // 게시물마다 개별 컨트롤러를 생성하여 글자 섞임 방지
                      _commentControllers.putIfAbsent(
                        doc.id,
                        () => TextEditingController(),
                      );

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            // 1. 이미지 (비율 최적화하여 확대 문제 해결)
                            if (data['imageUrl'] != null)
                              GestureDetector(
                                onTap: () => _showFullImage(data['imageUrl']),
                                child: Image.network(
                                  data['imageUrl'],
                                  height: 250,
                                  width: double.infinity,
                                  fit: BoxFit.contain, // 사진이 잘리지 않게 조정
                                ),
                              ),

                            // 2. 게시글 내용 및 삭제 버튼
                            ListTile(
                              title: Text(data['content'] ?? ''),
                              subtitle: Text(
                                data['timestamp'] != null
                                    ? DateFormat(
                                        'yyyy-MM-dd HH:mm',
                                      ).format(data['timestamp'].toDate())
                                    : '방금 전',
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
                            const Divider(),

                            // 3. 실시간 댓글 리스트
                            StreamBuilder<QuerySnapshot>(
                              stream: _posts
                                  .doc(doc.id)
                                  .collection('comments')
                                  .orderBy('timestamp')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox();
                                return Column(
                                  children: snapshot.data!.docs.map((
                                    commentDoc,
                                  ) {
                                    Map<String, dynamic> cData =
                                        commentDoc.data()
                                            as Map<String, dynamic>;
                                    return ListTile(
                                      dense: true,
                                      title: Text(cData['content'] ?? ''),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () =>
                                            commentDoc.reference.delete(),
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),

                            // 4. 댓글 입력창 (게시물별 독립 컨트롤러 연결)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _commentControllers[doc
                                              .id], // 개별 컨트롤러 연결
                                      decoration: const InputDecoration(
                                        hintText: '댓글 입력...',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.check),
                                    onPressed: () {
                                      final text =
                                          _commentControllers[doc.id]!.text;
                                      if (text.isNotEmpty) {
                                        _posts
                                            .doc(doc.id)
                                            .collection('comments')
                                            .add({
                                              'content': text,
                                              'timestamp':
                                                  FieldValue.serverTimestamp(),
                                            });
                                        _commentControllers[doc.id]!
                                            .clear(); // 해당 칸만 비우기
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ); // ListView 끝
                },
              ),
            ), // Expanded 끝
            if (_pickedFile != null)
              Container(
                color: Colors.grey[200],
                padding: const EdgeInsets.all(8),
                child: Text(
                  '✅ 이미지 선택 완료: ${_pickedFile!.name}',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    onPressed: _pickImage,
                  ), // 카메라 아이콘
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '내용 입력...',
                      ), // 힌트 문구 변경 확인용
                    ),
                  ),
                  _isLoading
                      ? const SizedBox(
                          width: 48, // 기존 아이콘 버튼과 비슷한 크기를 맞추기 위해 추가
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _addPost,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
