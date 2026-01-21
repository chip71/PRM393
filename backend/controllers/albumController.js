const Album = require("../models/albums.js");
const Artist = require("../models/artists.js");
const Genre = require("../models/genres.js");

/* ============================================
   🔹 GET all albums (with artist + genre)
============================================ */
const getAlbums = async (req, res) => {
  try {
    const albums = await Album.find()
      .populate("artistID", "name image spotify youtube")
      .populate("genreID", "name");
    res.json(albums);
  } catch (err) {
    console.error("❌ Error fetching albums:", err);
    res.status(500).json({ message: "Server error fetching albums" });
  }
};

/* ============================================
   🔹 GET album by ID
============================================ */
const getAlbumById = async (req, res) => {
  try {
    const album = await Album.findById(req.params.id)
      .populate("artistID", "name image spotify youtube")
      .populate("genreID", "name");

    if (!album) return res.status(404).json({ message: "Album not found" });
    res.json(album);
  } catch (err) {
    console.error(`❌ Error fetching album ${req.params.id}:`, err);
    res.status(500).json({ message: "Server error fetching album" });
  }
};

/* ============================================
   🔹 GET albums by artist
============================================ */
const getAlbumsByArtistId = async (req, res) => {
  try {
    const artistId = req.params.id;
    const artistExists = await Artist.findById(artistId);
    if (!artistExists)
      return res.status(404).json({ message: "Artist not found" });

    const albums = await Album.find({ artistID: artistId })
      .populate("artistID", "name image")
      .populate("genreID", "name");

    res.json(albums);
  } catch (err) {
    console.error(`❌ Error fetching albums for artist ${req.params.id}:`, err);
    res.status(500).json({ message: "Server error fetching artist albums" });
  }
};

/* ============================================
   🔹 GET albums by genre (for recommendations)
============================================ */
const getAlbumsByGenreId = async (req, res) => {
  try {
    const genreId = req.params.id;
    const excludeAlbumId = req.query.exclude;
    const query = excludeAlbumId
      ? { genreID: genreId, _id: { $ne: excludeAlbumId } }
      : { genreID: genreId };

    const albums = await Album.find(query)
      .populate("artistID", "name")
      .populate("genreID", "name");

    res.json(albums);
  } catch (err) {
    console.error(`❌ Error fetching albums by genre ${req.params.id}:`, err);
    res.status(500).json({ message: "Server error fetching genre albums" });
  }
};

/* ============================================
   🔹 CREATE album (admin)
============================================ */
const createAlbum = async (req, res) => {
  try {
    const album = new Album({
      name: req.body.name,
      artistID: req.body.artistID,
      genreID: req.body.genreID,
      description: req.body.description,
      format: req.body.format,
      price: req.body.price,
      stock: req.body.stock,
      spotify: req.body.spotify,
      youtube: req.body.youtube,
      image: req.body.image, // <- chỉ link ảnh
      currency: req.body.currency || "VND",
    });

    await album.save();

    const populated = await album.populate([
      { path: "artistID", select: "name" },
      { path: "genreID", select: "name" },
    ]);

    res.status(201).json(populated);
  } catch (err) {
    console.error("❌ Error creating album:", err);
    res.status(400).json({
      message: "Failed to create album",
      error: err.message,
    });
  }
};

/* ============================================
   🔹 UPDATE album (admin)
============================================ */
const updateAlbum = async (req, res) => {
  try {
    const album = await Album.findById(req.params.id);
    if (!album) return res.status(404).json({ message: "Album not found" });

    Object.assign(album, req.body);
    const updated = await album.save();

    const populated = await updated.populate([
      { path: "artistID", select: "name" },
      { path: "genreID", select: "name" },
    ]);

    res.json(populated);
  } catch (err) {
    console.error(`❌ Error updating album ${req.params.id}:`, err);
    res.status(400).json({
      message: "Failed to update album",
      error: err.message,
    });
  }
};

/* ============================================
   🔹 DELETE album (admin)
============================================ */
const deleteAlbum = async (req, res) => {
  try {
    const album = await Album.findById(req.params.id);
    if (!album) return res.status(404).json({ message: "Album not found" });

    await album.deleteOne();
    res.json({ message: "Album deleted successfully" });
  } catch (err) {
    console.error(`❌ Error deleting album ${req.params.id}:`, err);
    res.status(500).json({
      message: "Failed to delete album",
      error: err.message,
    });
  }
};

module.exports = {
  getAlbums,
  getAlbumById,
  getAlbumsByArtistId,
  getAlbumsByGenreId,
  createAlbum,
  updateAlbum,
  deleteAlbum,
};
