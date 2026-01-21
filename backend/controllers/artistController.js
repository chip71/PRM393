const Artist = require('../models/artists.js');
const Album = require('../models/albums.js');

// ======================================
// GET all artists
// ======================================
const getArtists = async (req, res) => {
  try {
    const artists = await Artist.find(); // lấy tất cả trường
    res.json(artists);
  } catch (err) {
    console.error('Error fetching artists:', err);
    res.status(500).json({ message: 'Server error fetching artists' });
  }
};

// ======================================
// GET single artist by ID
// ======================================
const getArtistById = async (req, res) => {
  try {
    const artistId = req.params.id;
    const artist = await Artist.findById(artistId);
    if (!artist) return res.status(404).json({ message: 'Artist not found' });

    // option: populate albums
    const albums = await Album.find({ artistID: artistId })
      .select('name image releaseYear genreID')
      .populate('genreID', 'name');

    res.json({
      ...artist.toObject(),
      albums,
    });
  } catch (err) {
    if (err.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid artist ID' });
    }
    console.error(`Error fetching artist ${req.params.id}:`, err);
    res.status(500).json({ message: 'Server error fetching artist' });
  }
};

// ======================================
// CREATE artist
// ======================================
const createArtist = async (req, res) => {
  try {
    const artist = new Artist({
      name: req.body.name,
      image: req.body.image,
      description: req.body.description,
      spotify: req.body.spotify,
      youtube: req.body.youtube,
    });
    await artist.save();
    res.status(201).json(artist);
  } catch (err) {
    console.error('Error creating artist:', err);
    res.status(400).json({ message: 'Failed to create artist', error: err.message });
  }
};

// ======================================
// UPDATE artist
// ======================================
const updateArtist = async (req, res) => {
  try {
    const artist = await Artist.findById(req.params.id);
    if (!artist) return res.status(404).json({ message: 'Artist not found' });

    Object.assign(artist, req.body);
    const updated = await artist.save();
    res.json(updated);
  } catch (err) {
    console.error(`Error updating artist ${req.params.id}:`, err);
    res.status(400).json({ message: 'Failed to update artist', error: err.message });
  }
};

// ======================================
// DELETE artist
// ======================================
const deleteArtist = async (req, res) => {
  try {
    const artist = await Artist.findById(req.params.id);
    if (!artist) return res.status(404).json({ message: 'Artist not found' });

    await artist.deleteOne();
    res.json({ message: 'Artist deleted successfully' });
  } catch (err) {
    console.error(`Error deleting artist ${req.params.id}:`, err);
    res.status(500).json({ message: 'Failed to delete artist', error: err.message });
  }
};

module.exports = {
  getArtists,
  getArtistById,
  createArtist,
  updateArtist,
  deleteArtist,
};
