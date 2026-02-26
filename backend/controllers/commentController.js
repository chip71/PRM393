const Comment = require('../models/comments');

// Add a new comment (user or admin)
exports.addComment = async (req, res) => {
    try {
        const { albumId, userId, username, role, content, rating, parentId } = req.body;

        const newComment = new Comment({
            albumId,
            userId,
            username,
            role: role || 'customer',
            parentId: parentId || null,
            content,
            rating: rating || 5
        });

        await newComment.save();
        res.status(201).json(newComment);
    } catch (err) {
        res.status(400).json({ message: 'Error posting comment', error: err.message });
    }
};

// Get comments for an album
exports.getAlbumComments = async (req, res) => {
    try {
        // return all comments for the album (flat list). Frontend will build tree.
        const comments = await Comment.find({ albumId: req.params.albumId })
                                     .sort({ createdAt: 1 }); // oldest first for threading
        res.json(comments);
    } catch (err) {
        res.status(500).json({ message: 'Error fetching comments', error: err.message });
    }
};
