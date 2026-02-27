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

// --- ADMIN HELPERS ------------------------------------------------

// Retrieve every comment in the system (for moderation dashboard)
exports.getAllComments = async (req, res) => {
    try {
        const comments = await Comment.find().sort({ createdAt: 1 });
        res.json(comments);
    } catch (err) {
        res.status(500).json({ message: 'Error retrieving comments', error: err.message });
    }
};

// Delete a specific comment by id (admin only)
exports.deleteComment = async (req, res) => {
    try {
        const deleted = await Comment.findByIdAndDelete(req.params.id);
        if (!deleted) return res.status(404).json({ message: 'Comment not found' });
        res.json({ message: 'Deleted' });
    } catch (err) {
        res.status(500).json({ message: 'Error deleting comment', error: err.message });
    }
};

// Update a comment (e.g. edit content)
exports.updateComment = async (req, res) => {
    try {
        const updated = await Comment.findByIdAndUpdate(
            req.params.id,
            { $set: req.body },
            { new: true }
        );
        if (!updated) return res.status(404).json({ message: 'Comment not found' });
        res.json(updated);
    } catch (err) {
        res.status(500).json({ message: 'Error updating comment', error: err.message });
    }
};
