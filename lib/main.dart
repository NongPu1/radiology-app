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
      title: 'Seoul Medical Center',
      theme: ThemeData(
        primaryColor: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
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

  // 카테고리 설정
  String _mainCategory = '근무표-본원';
  String _subCategory = '일반'; // 인수인계용 (DR, CT, MR 등)
  String _selectedYear = DateFormat('yyyy').format(DateTime.now());
  String _selectedMonth = DateFormat('M').format(DateTime.now());

  List<XFile> _pickedFiles = [];
  String _currentUserName = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLoginDialog());
  }

  // --- 사용자 로그인 (이름 입력) ---
  void _showLoginDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('사용자 이름 입력'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '이름을 입력하세요 (예: 홍길동)'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() => _currentUserName = nameController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // --- 이미지 피커 ---
  Future<void> _pickImage() async {
    final images = await ImagePicker().pickMultiImage();
    if (images.isNotEmpty) setState(() => _pickedFiles = images);
  }

  // --- 게시글 추가 로직 (수정본) ---
  void _addPost() async {
    if (_controller.text.trim().isEmpty && _pickedFiles.isEmpty) return;
    List<String> imageUrls = [];
    setState(() => _isLoading = true);

    try {
      for (var file in _pickedFiles) {
        final ref = FirebaseStorage.instance.ref().child(
          'post_images/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
        );
        await ref.putData(await file.readAsBytes());
        imageUrls.add(await ref.getDownloadURL());
      }

      // 중요: 모든 필드를 동일한 레벨(최상위)에 나열해야 합니다.
      await _posts.add({
        'mainCategory': _mainCategory,
        'subCategory': _mainCategory == '인수인계' ? _subCategory : '일반',
        'year': _selectedYear,
        'month': _selectedMonth,
        'content': _controller.text,
        'imageUrls': imageUrls, // 이미지 리스트만 따로 보관
        'userName': _currentUserName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _controller.clear();
      setState(() => _pickedFiles = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 댓글 추가 로직 ---
  Future<void> _addComment(String postId, String text) async {
    if (text.trim().isEmpty) return;
    await _posts.doc(postId).collection('comments').add({
      'content': text,
      'userName': _currentUserName,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _commentControllers[postId]?.clear();
  }

  // --- 게시글 삭제 ---
  Future<void> _deletePost(String docId, List<dynamic>? imageUrls) async {
    if (imageUrls != null) {
      for (var url in imageUrls) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (_) {}
      }
    }
    await _posts.doc(docId).delete();
  }

  // --- 게시글 수정 다이얼로그 ---
  void _showEditPostDialog(String docId, String currentContent) {
    final TextEditingController editController = TextEditingController(
      text: currentContent,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('게시글 수정'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await _posts.doc(docId).update({
                'content': editController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('수정'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 2,
        title: const Text(
          'Seoul Medical Center',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 1. 메인 카테고리 선택 (가로 스크롤)
          Container(
            color: Colors.blue.shade50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                children: ['근무표-본원', '근무표-ER', '인수인계', '식단표', '전화번호부', '요청/민원']
                    .map((cat) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: _mainCategory == cat,
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _mainCategory == cat
                                ? Colors.white
                                : Colors.black,
                          ),
                          onSelected: (selected) => setState(() {
                            _mainCategory = cat;
                            _subCategory = 'DR'; // 인수인계 기본값
                          }),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ),

          // 2. 인수인계 하위 카테고리 (인수인계 선택시에만 표시)
          if (_mainCategory == '인수인계')
            Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['DR', 'CT', 'MR', 'ANGIO', 'ER', 'Night'].map((
                    sub,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ActionChip(
                        backgroundColor: _subCategory == sub
                            ? Colors.blue.shade200
                            : Colors.grey.shade200,
                        label: Text(sub, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() => _subCategory = sub),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // 3. 날짜 필터 (근무표 및 인수인계에서 표시)
          if (['근무표-본원', '근무표-ER', '인수인계'].contains(_mainCategory))
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: _selectedYear,
                    items: ['2024', '2025', '2026']
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y년')),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedYear = val!),
                  ),
                  const SizedBox(width: 20),
                  DropdownButton<String>(
                    value: _selectedMonth,
                    items: List.generate(12, (i) => (i + 1).toString())
                        .map(
                          (m) => DropdownMenuItem(value: m, child: Text('$m월')),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedMonth = val!),
                  ),
                ],
              ),
            ),

          // 4. 메인 게시글 리스트
          Expanded(
            child: StreamBuilder(
              stream: _buildQuery().snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty)
                  return const Center(child: Text('등록된 게시글이 없습니다.'));

                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>;
                    _commentControllers.putIfAbsent(
                      doc.id,
                      () => TextEditingController(),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 이미지 표시 영역
                          if (data['imageUrls'] != null &&
                              (data['imageUrls'] as List).isNotEmpty)
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: (data['imageUrls'] as List).length,
                                itemBuilder: (context, index) =>
                                    GestureDetector(
                                      onTap: () => _showFullImage(
                                        data['imageUrls'][index],
                                      ),
                                      child: Container(
                                        width: 250,
                                        margin: const EdgeInsets.all(8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            data['imageUrls'][index],
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                              ),
                            ),

                          ListTile(
                            title: Text(
                              data['content'] ?? '',
                              style: const TextStyle(fontSize: 15),
                            ),
                            subtitle: Text(
                              '${data['userName']} | ${data['timestamp'] != null ? DateFormat('MM/dd HH:mm').format(data['timestamp'].toDate()) : '방금 전'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_note,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  onPressed: () => _showEditPostDialog(
                                    doc.id,
                                    data['content'],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _deletePost(doc.id, data['imageUrls']),
                                ),
                              ],
                            ),
                          ),

                          // 댓글 섹션
                          const Divider(height: 1),
                          _buildCommentSection(doc.id),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(),

          // 5. 하단 입력창
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.image,
                    color: _pickedFiles.isNotEmpty ? Colors.green : Colors.blue,
                  ),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '내용을 입력하세요...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _addPost,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Query _buildQuery() {
    // 1. 공통 쿼리 시작
    Query query = _posts;

    if (_mainCategory == '인수인계') {
      // 인수인계: 5개 필드 조합 색인 필요
      query = query
          .where('mainCategory', isEqualTo: _mainCategory)
          .where('subCategory', isEqualTo: _subCategory)
          .where('year', isEqualTo: _selectedYear)
          .where('month', isEqualTo: _selectedMonth);
    } else if (['근무표-본원', '근무표-ER'].contains(_mainCategory)) {
      // 근무표: 4개 필드 조합 색인 필요
      query = query
          .where('mainCategory', isEqualTo: _mainCategory)
          .where('year', isEqualTo: _selectedYear)
          .where('month', isEqualTo: _selectedMonth);
    } else {
      // 나머지(식단표 등): 1개 필드 조합 색인 필요
      query = query.where('mainCategory', isEqualTo: _mainCategory);
    }

    // 모든 경우에 timestamp 정렬 추가
     return query.orderBy('timestamp', descending: true);
  }

  // --- 댓글 섹션 위젯 ---
  Widget _buildCommentSection(String postId) {
    return Column(
      children: [
        StreamBuilder(
          stream: _posts
              .doc(postId)
              .collection('comments')
              .orderBy('timestamp')
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
              return const SizedBox();
            return Container(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Column(
                children: snapshot.data!.docs.map((cDoc) {
                  Map<String, dynamic> cData =
                      cDoc.data() as Map<String, dynamic>;
                  return Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${cData['userName']}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              TextSpan(
                                text: cData['content'],
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.grey,
                        ),
                        onPressed: () => _posts
                            .doc(postId)
                            .collection('comments')
                            .doc(cDoc.id)
                            .delete(),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentControllers[postId],
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '댓글 입력...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 18, color: Colors.blue),
                onPressed: () =>
                    _addComment(postId, _commentControllers[postId]!.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
