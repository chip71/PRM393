import 'package:flutter/material.dart';
import 'album_card.dart';

class AlbumRow extends StatelessWidget {
  final String? title;
  final List<dynamic> albums;
  final List<dynamic> artists;
  final List<dynamic> genres;

  const AlbumRow({
    super.key,
    this.title,
    required this.albums,
    required this.artists,
    required this.genres,
  });

  // Helper tìm Artist: Chuyển đổi ID sang String để so sánh chính xác với MongoDB
  Map<String, dynamic> _getArtist(dynamic artistID) {
    if (artistID == null) return {'name': 'Unknown Artist'};
    
    // Nếu artistID đã là Object (do populate), trả về luôn
    if (artistID is Map) return Map<String, dynamic>.from(artistID);

    return artists.firstWhere(
      (a) => a['_id'].toString() == artistID.toString(),
      orElse: () => {'name': 'Unknown Artist'},
    );
  }

  // Helper tìm Genre: Tương tự như Artist
  Map<String, dynamic> _getGenre(dynamic genreID) {
    if (genreID == null) return {'name': 'Unknown Genre'};

    if (genreID is Map) return Map<String, dynamic>.from(genreID);

    return genres.firstWhere(
      (g) => g['_id'].toString() == genreID.toString(),
      orElse: () => {'name': 'Unknown Genre'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),

          // ListView nằm ngang
          SizedBox(
            // Tăng chiều cao lên 280 để đủ chỗ cho Tên Album, Artist, Genre và Giá VND (phòng tránh lỗi Overflow)
            height: 280, 
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];

                // Clone album và đính kèm thông tin Artist/Genre đã tìm thấy
                final Map<String, dynamic> albumWithDetails = Map.from(album);
                albumWithDetails['artistID'] = _getArtist(album['artistID']);
                albumWithDetails['genreID'] = _getGenre(album['genreID']);

                return AlbumCard(album: albumWithDetails);
              },
            ),
          ),
        ],
      ),
    );
  }
}