const Genre = require('../models/genres.js');

// GET all genres
const getGenres = async (req, res) => {
  try {
    const genres = await Genre.find();
    res.json(genres);
  } catch (err) {
    console.error('Error fetching genres:', err);
    res.status(500).json({ message: 'Server error fetching genres' });
  }
};

// GET a single genre by ID
const getGenreById = async (req, res) => {
  try {
    const genre = await Genre.findById(req.params.id);

    if (!genre) {
      return res.status(404).json({ message: 'Genre not found' });
    }
    res.json(genre);
  } catch (err) {
    if (err.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid Genre ID format' });
    }
    console.error(`Error fetching genre ${req.params.id}:`, err);
    res.status(500).json({ message: 'Server error fetching genre' });
  }
};

// CREATE a new genre
const createGenre = async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ message: 'Genre name is required' });
    }

    const newGenre = new Genre({ name: name.trim() });
    await newGenre.save();

    res.status(201).json({ message: 'Genre created successfully', genre: newGenre });
  } catch (err) {
    console.error('Error creating genre:', err);
    res.status(500).json({ message: 'Server error creating genre' });
  }
};

// UPDATE a genre by ID
const updateGenre = async (req, res) => {
  try {
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ message: 'Genre name is required' });
    }

    const genre = await Genre.findByIdAndUpdate(
      req.params.id,
      { name: name.trim() },
      { new: true, runValidators: true }
    );

    if (!genre) {
      return res.status(404).json({ message: 'Genre not found' });
    }

    res.json({ message: 'Genre updated successfully', genre });
  } catch (err) {
    if (err.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid Genre ID format' });
    }
    console.error(`Error updating genre ${req.params.id}:`, err);
    res.status(500).json({ message: 'Server error updating genre' });
  }
};

// DELETE a genre by ID
const deleteGenre = async (req, res) => {
  try {
    const genre = await Genre.findByIdAndDelete(req.params.id);
    if (!genre) {
      return res.status(404).json({ message: 'Genre not found' });
    }
    res.json({ message: 'Genre deleted successfully' });
  } catch (err) {
    if (err.name === 'CastError') {
      return res.status(400).json({ message: 'Invalid Genre ID format' });
    }
    console.error(`Error deleting genre ${req.params.id}:`, err);
    res.status(500).json({ message: 'Server error deleting genre' });
  }
};

module.exports = {
  getGenres,
  getGenreById,
  createGenre,
  updateGenre,
  deleteGenre,
};
