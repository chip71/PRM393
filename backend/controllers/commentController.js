const Comment = require('../models/comments');
const User = require('../models/users'); // thêm dòng này

// Add a new comment
exports.addComment = async (req, res) => {
    try {
        const { albumId, userId, content, rating, parentId } = req.body;

        // Tìm user để lấy username
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        const newComment = new Comment({
            albumId,
            userId,
            name: { type: String, required: true },
            parentId: parentId || null,
            content,
            rating: rating || 5
        });

        await newComment.save();

        res.status(201).json(newComment);
    } catch (err) {
        res.status(400).json({
            message: 'Error posting comment',
            error: err.message
        });
    }
};


// Get comments for an album
exports.getAlbumComments = async (req, res) => {
    try {
        const comments = await Comment.find({ albumId: req.params.albumId })
            .sort({ createdAt: 1 });

        res.json(comments);
    } catch (err) {
        res.status(500).json({
            message: 'Error fetching comments',
            error: err.message
        });
    }
};


// Get all comments (Admin)
exports.getAllComments = async (req, res) => {
    try {
        const comments = await Comment.find()
            .sort({ createdAt: -1 })
            .populate('albumId', 'title')
            .populate('userId', 'username');

        res.json(comments);
    } catch (err) {
        res.status(500).json({
            message: 'Error fetching comments',
            error: err.message
        });
    }
};


// Delete comment (Admin)
exports.deleteComment = async (req, res) => {
    try {
        await Comment.findByIdAndDelete(req.params.id);
        res.json({ message: 'Comment deleted successfully' });
    } catch (err) {
        res.status(500).json({
            message: 'Error deleting comment',
            error: err.message
        });
    }
};


// Update comment
exports.updateComment = async (req, res) => {
    try {
        const { content, rating } = req.body;

        const updated = await Comment.findByIdAndUpdate(
            req.params.id,
            { content, rating },
            { new: true }
        );

        res.json(updated);
    } catch (err) {
        res.status(500).json({
            message: 'Error updating comment',
            error: err.message
        });
    }
};