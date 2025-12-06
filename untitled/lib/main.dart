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

// ★ 영화 목록 화면 (Stateful)
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
    // 주의: adb reverse tcp:44444 tcp:44444 명령어를 터미널에 입력해야 함!
    final url = Uri.parse('http://localhost:44444/MoviesApi/GetMovies');

    try {
      print('데이터 요청 시작: $url');
      final response = await http.get(url);

      print('응답 코드: ${response.statusCode}'); // 200이면 성공

      if (response.statusCode == 200) {
        setState(() {
          movies = jsonDecode(response.body); // 받은 데이터를 리스트에 넣음
        });
      } else {
        print('서버 에러: ${response.body}');
      }
    } catch (e) {
      print('에러 났슈: $e');
    }
  }

  // ★ 화면 그리기
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('웅캬캬 영화관')),
      body: movies.isEmpty
          ? const Center(child: CircularProgressIndicator()) // 로딩 중
          : RefreshIndicator(
        // 새로고침 기능
        onRefresh: fetchMovies,
        color: Colors.white,
        backgroundColor: Colors.redAccent,
        child: ListView.builder(
          // 데이터가 적어도 당겨서 새로고침 가능하게 설정
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: movies.length,
          itemBuilder: (context, index) {
            final movie = movies[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                // 포스터 이미지
                leading: movie['PosterURL'] != null && movie['PosterURL'] != ''
                    ? Image.network(
                  movie['PosterURL'],
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.movie),
                )
                    : const Icon(Icons.movie),
                // 제목
                title: Text(movie['Title'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                // 부제목 (감독 | 연도)
                subtitle: Text('${movie['Director']} | ${movie['Year']}'),
                // 화살표 아이콘
                trailing: const Icon(Icons.arrow_forward_ios),
                // 클릭 시 상세 페이지로 이동
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MovieDetailPage(movie: movie),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

// ★ 영화 상세 화면 (Stateless)
class MovieDetailPage extends StatelessWidget {
  final Map movie; // 선택된 영화 데이터 받기

  const MovieDetailPage({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(movie['Title'])),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 대문짝만한 포스터
            movie['PosterURL'] != null && movie['PosterURL'] != ''
                ? Image.network(
              movie['PosterURL'],
              height: 400,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
              const SizedBox(height: 300, child: Center(child: Icon(Icons.broken_image, size: 100))),
            )
                : Container(
              height: 300,
              color: Colors.grey[800],
              child: const Icon(Icons.movie, size: 100),
            ),

            // 2. 텍스트 정보 영역
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목 & 연도
                  Text(
                    '${movie['Title']} (${movie['Year']})',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // 감독 & 주연
                  Text(
                    '감독: ${movie['Director']}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  Text(
                    '주연: ${movie['LeadActor']}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const Divider(height: 30), // 구분선

                  // 줄거리
                  const Text(
                    "줄거리",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    movie['Plot'] ?? "줄거리가 없습니다.",
                    style: const TextStyle(fontSize: 16, height: 1.5),
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