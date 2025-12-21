import 'dart:io'; // 보안 인증서 무시용
import 'dart:convert'; // JSON 변환용
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // http 통신용

void main() {
  // 1. 보안 인증서(HTTPS) 에러 무시 설정 (개발용)
  HttpOverrides.global = MyHttpOverrides();

  // 2. 앱 실행
  runApp(const MyApp());
}

// ★ 보안 인증서 무시 클래스
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

// ★ 앱의 시작점 (테마 설정)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 오른쪽 위 'DEBUG' 띠 제거
      title: '웅캬캬 영화관',
      theme: ThemeData.dark(), // 다크 모드 적용
      home: const MovieListPage(),
    );
  }
}

// ★ 1. 영화 목록 화면
class MovieListPage extends StatefulWidget {
  const MovieListPage({super.key});

  @override
  State<MovieListPage> createState() => _MovieListPageState();
}

class _MovieListPageState extends State<MovieListPage> {
  List movies = []; // 영화 데이터를 담을 리스트

  @override
  void initState() {
    super.initState();
    fetchMovies(); // 앱 켜지면 데이터 가져오기 시작
  }

  // ★ 서버에서 데이터 가져오는 함수
  Future<void> fetchMovies() async {
    // 주의: adb reverse tcp:44444 tcp:44444 필수!
    final url = Uri.parse('http://localhost:44444/MoviesApi/GetMovies');

    try {
      print('데이터 요청 시작: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          movies = jsonDecode(response.body);
        });
      } else {
        print('서버 에러: ${response.body}');
      }
    } catch (e) {
      print('에러 났슈: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('웅캬캬 영화관')),

      // ★ 우측 하단 영화 추가 버튼 (+)
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MovieAddPage()),
          );
          if (result == true) fetchMovies(); // 저장했으면 새로고침
        },
      ),

      body: movies.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchMovies,
        color: Colors.white,
        backgroundColor: Colors.redAccent,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: movie['PosterURL'] != null && movie['PosterURL'] != ''
                    ? Image.network(
                  movie['PosterURL'],
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.movie),
                )
                    : const Icon(Icons.movie),
                title: Text(movie['Title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${movie['Director']} | ${movie['Year']}'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  // 상세 페이지로 이동 (갔다 오면 새로고침)
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailPage(movie: movie),
                    ),
                  );
                  if (result == true) fetchMovies();
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ★ 2. 영화 상세 화면 (수정/삭제 기능 포함)
class MovieDetailPage extends StatefulWidget {
  final Map movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late Map currentMovie;

  @override
  void initState() {
    super.initState();
    currentMovie = widget.movie;
  }

  // 삭제 함수
  Future<void> deleteMovie() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("영화 삭제"),
        content: const Text("정말 이 영화를 지우시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("삭제", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final url = Uri.parse('http://localhost:44444/MoviesApi/DeleteMovie?id=${currentMovie['ID']}');
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); // 삭제 성공 신호 보냄
      }
    } catch (e) {
      print("에러: $e");
    }
  }

  // 수정 화면 이동
  Future<void> goToEditPage() async {
    final updatedMovie = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieEditPage(movie: currentMovie),
      ),
    );

    if (updatedMovie != null) {
      setState(() {
        currentMovie = updatedMovie;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentMovie['Title']),
        actions: [
          IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: goToEditPage),
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: deleteMovie),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            currentMovie['PosterURL'] != null && currentMovie['PosterURL'] != ''
                ? Image.network(
              currentMovie['PosterURL'],
              height: 400,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
              const SizedBox(height: 300, child: Center(child: Icon(Icons.broken_image, size: 100))),
            )
                : Container(height: 300, color: Colors.grey[800], child: const Icon(Icons.movie, size: 100)),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${currentMovie['Title']} (${currentMovie['Year']})', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('감독: ${currentMovie['Director']}', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  Text('주연: ${currentMovie['LeadActor']}', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  const Divider(height: 30),
                  const Text("줄거리", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                  const SizedBox(height: 10),
                  Text(currentMovie['Plot'] ?? "줄거리가 없습니다.", style: const TextStyle(fontSize: 16, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ★ 3. 영화 추가 화면
class MovieAddPage extends StatefulWidget {
  const MovieAddPage({super.key});

  @override
  State<MovieAddPage> createState() => _MovieAddPageState();
}

class _MovieAddPageState extends State<MovieAddPage> {
  final _titleController = TextEditingController();
  final _directorController = TextEditingController();
  final _actorController = TextEditingController();
  final _yearController = TextEditingController();
  final _posterController = TextEditingController();
  final _plotController = TextEditingController();

  Future<void> saveMovie() async {
    if (_titleController.text.isEmpty) return;

    final Map<String, dynamic> movieData = {
      'Title': _titleController.text,
      'Director': _directorController.text,
      'LeadActor': _actorController.text,
      'Year': int.tryParse(_yearController.text) ?? 2024,
      'PosterURL': _posterController.text,
      'Plot': _plotController.text,
    };

    final url = Uri.parse('http://localhost:44444/MoviesApi/AddMovie');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(movieData),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 영화 추가')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: '영화 제목 (필수)')),
            TextField(controller: _directorController, decoration: const InputDecoration(labelText: '감독')),
            TextField(controller: _actorController, decoration: const InputDecoration(labelText: '주연 배우')),
            TextField(controller: _yearController, decoration: const InputDecoration(labelText: '개봉 연도'), keyboardType: TextInputType.number),
            TextField(controller: _posterController, decoration: const InputDecoration(labelText: '포스터 URL')),
            const SizedBox(height: 10),
            TextField(controller: _plotController, decoration: const InputDecoration(labelText: '줄거리'), maxLines: 3),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: saveMovie,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text('저장하기', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ★ 4. 영화 수정 화면
class MovieEditPage extends StatefulWidget {
  final Map movie;

  const MovieEditPage({super.key, required this.movie});

  @override
  State<MovieEditPage> createState() => _MovieEditPageState();
}

class _MovieEditPageState extends State<MovieEditPage> {
  late TextEditingController _titleController;
  late TextEditingController _directorController;
  late TextEditingController _actorController;
  late TextEditingController _yearController;
  late TextEditingController _posterController;
  late TextEditingController _plotController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.movie['Title']);
    _directorController = TextEditingController(text: widget.movie['Director']);
    _actorController = TextEditingController(text: widget.movie['LeadActor']);
    _yearController =
        TextEditingController(text: widget.movie['Year'].toString());
    _posterController = TextEditingController(text: widget.movie['PosterURL']);
    _plotController = TextEditingController(text: widget.movie['Plot']);
  }

  Future<void> editMovie() async {
    final Map<String, dynamic> movieData = {
      'ID': widget.movie['ID'],
      'Title': _titleController.text,
      'Director': _directorController.text,
      'LeadActor': _actorController.text,
      'Year': int.tryParse(_yearController.text) ?? 0,
      'PosterURL': _posterController.text,
      'Plot': _plotController.text,
    };

    final url = Uri.parse('http://localhost:44444/MoviesApi/EditMovie');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(movieData),
      );
      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, movieData);
      }
    } catch (e) {
      print('에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('영화 정보 수정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController,
                decoration: const InputDecoration(labelText: '영화 제목')),
            TextField(controller: _directorController,
                decoration: const InputDecoration(labelText: '감독')),
            TextField(controller: _actorController,
                decoration: const InputDecoration(labelText: '주연 배우')),
            TextField(controller: _yearController,
                decoration: const InputDecoration(labelText: '개봉 연도'),
                keyboardType: TextInputType.number),
            TextField(controller: _posterController,
                decoration: const InputDecoration(labelText: '포스터 URL')),
            const SizedBox(height: 10),
            TextField(controller: _plotController,
                decoration: const InputDecoration(labelText: '줄거리'),
                maxLines: 3),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: editMovie,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent),
                child: const Text('수정 완료',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}