import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlbumCard extends StatefulWidget {
  final dynamic album;

  const AlbumCard({super.key, required this.album});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    bool isSoldOut = (widget.album['stock'] ?? 0) <= 0;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    if (isSoldOut) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSoldOut = (widget.album['stock'] ?? 0) <= 0;
    final String artistName = widget.album['artistID'] is Map
        ? (widget.album['artistID']['name'] ?? 'Unknown Artist')
        : 'Unknown Artist';
    final String genreName = widget.album['genreID'] is Map
        ? (widget.album['genreID']['name'] ?? 'Genre')
        : 'Genre';
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16, bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/album-detail', arguments: widget.album['_id'].toString());
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min, // QUAN TRỌNG: Chỉ chiếm không gian cần thiết
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Phần hình ảnh - Giữ AspectRatio để ảnh luôn vuông và không bị tràn
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: isSoldOut ? 0.6 : 1.0,
                        child: Image.network(
                          widget.album['image'] ?? '',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.album, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    if (isSoldOut)
                      Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'SOLD OUT',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Thông tin văn bản
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  // Dùng Wrap hoặc Row với Flexible để tránh tràn giá tiền
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          genreName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ),
                      if (widget.album['price'] != null)
                        Text(
                          currencyFormat.format(widget.album['price']),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueAccent,
                          ),
                        ),
                    ],
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