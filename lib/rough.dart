import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:status_view/status_view.dart';
import 'homepage.dart';
import 'package:carousel_slider/carousel_slider.dart';


class StatusUploadPage extends StatefulWidget {
  @override
  _StatusUploadPageState createState() => _StatusUploadPageState();
}

class _StatusUploadPageState extends State<StatusUploadPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  List<File> _selectedImages = [];
  List<File> _selectedVideos = [];



  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _uploadStatus({String? text, File? mediaFile, String? mediaType}) async {
    User? user = _auth.currentUser;
    if (user == null) {
      print("No user signed in");
      return;
    }

    setState(() {
      _isUploading = true;
    });

    String? mediaUrl;

    if (mediaFile != null && mediaType != null) {
      try {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';
        UploadTask uploadTask = _storage.ref('status/$fileName').putFile(mediaFile);
        TaskSnapshot snapshot = await uploadTask;
        mediaUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        print("Failed to upload media: $e");
      }
    }

    try {
      // Fetch current user's name from 'users' collection
      DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(user.uid).get();
      String? currentUserName = userSnapshot.get('name');

      String uploadDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Format current time to only include the time part
      String uploadTime = DateFormat.Hms().format(DateTime.now());

      DocumentReference docRef = await _firestore.collection('status').doc(user.uid).collection('statuses').add({
        'text': text ?? '',
        'mediaUrl': mediaUrl ?? '',
        'mediaType': mediaType ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false, // Initially mark as unseen
        'likeCount': 0, // Initial like count
        'likedBy': [], // List to store user IDs who liked the status
        'viewedById': [], // Initialize empty list for viewedById
        'viewedByName': [], // Initialize empty list for viewedByName
        'uploadTime': uploadTime,
        'uploadDate': uploadDate,
      });

      // Update status ID after successful upload
      String statusId = docRef.id;

      // Navigate back to StatusUploadPage
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StatusUploadPage()));
    } catch (e) {
      print("Failed to upload status: $e");
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final pickedFile = await (isVideo
        ? _picker.pickVideo(source: source, maxDuration: Duration(seconds: 30))
        : _picker.pickImage(source: source));

    if (pickedFile != null) {
      // Immediately upload the media without showing a dialog
      _uploadStatus(mediaFile: File(pickedFile.path), mediaType: isVideo ? 'video' : 'image');
    }
  }

  void _showTextDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Define a boolean variable to track if text is empty
        bool isTextEmpty = _textController.text.trim().isEmpty;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('Write Status'),
            content: TextField(
              controller: _textController,
              maxLines: null,
              onChanged: (text) {
                setState(() {
                  isTextEmpty = text.trim().isEmpty;
                });
              },
              decoration: InputDecoration(
                hintText: 'Write your status...',
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: isTextEmpty
                    ? null // Disable button if text is empty
                    : () {
                  _uploadStatus(text: _textController.text);
                  _textController.clear();
                  Navigator.pop(context);
                },
                child: Text('UPLOAD'),
              ),
            ],
          ),
        );
      },
    );
  }


  void _navigateToHomePage() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
  }

  void _showFullScreenStatusView(List<DocumentSnapshot> statuses, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenStatusView(statuses: statuses, initialIndex: initialIndex, currentUser: _auth.currentUser, auth: _auth),
      ),
    ).then((_) {
      setState(() {}); // Refresh the status view when returning from full screen
    });
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Upload Status'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: _navigateToHomePage,
          ),
        ),
        body: Center(
          child: user == null
              ? Text('No user signed in')
              : StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('status')
                .doc(user.uid)
                .collection('statuses')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('No statuses available');
              }

              List<DocumentSnapshot> statuses = snapshot.data!.docs;

              int seenCount = statuses.where((status) => (status.data() as Map<String, dynamic>?)?['seen'] == true).length;

              return GestureDetector(
                onTap: () => _showFullScreenStatusView(statuses, 0),
                child: StatusView(
                  radius: 40,
                  spacing: 15,
                  strokeWidth: 2,
                  indexOfSeenStatus: seenCount,
                  numberOfStatus: statuses.length,
                  padding: 4,
                  seenColor: Colors.grey,
                  unSeenColor: Colors.red,
                  centerImageUrl: "https://picsum.photos/200/300",
                ),
              );
            },
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            FloatingActionButton(
              onPressed: _showTextDialog,
              child: Icon(Icons.edit),
              tooltip: 'Upload Text Status',
            ),
            SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () => _pickMedia(ImageSource.gallery, false),
              child: Icon(Icons.image),
              tooltip: 'Upload Image',
            ),
            SizedBox(height: 16),
            FloatingActionButton(
              onPressed: () => _pickMedia(ImageSource.gallery, true),
              child: Icon(Icons.video_library),
              tooltip: 'Upload Video',
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenStatusView extends StatefulWidget {
  final List<DocumentSnapshot> statuses;
  final int initialIndex;
  final User? currentUser;
  final FirebaseAuth auth;

  FullScreenStatusView({
    required this.statuses,
    required this.initialIndex,
    required this.currentUser,
    required this.auth,
  });

  @override
  _FullScreenStatusViewState createState() => _FullScreenStatusViewState();
}

class _FullScreenStatusViewState extends State<FullScreenStatusView> {
  late PageController _pageController;

  bool _isAutoSliding = false;
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    currentUser = FirebaseAuth.instance.currentUser;
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _markStatusAsViewed(widget.statuses[widget.initialIndex]);

      _startAutoSlideShow();
      _preloadStatuses();
    });
  }


  void _startAutoSlideShow() {
    if (!_isAutoSliding) {
      _isAutoSliding = true;
      _autoSlideToNext();
    }
  }

  void _autoSlideToNext() async {
    Duration duration = await _getAutoSlideDuration(widget.statuses[_pageController.page!.round()]);
    await Future.delayed(duration);
    if (_pageController.page!.round() < widget.statuses.length - 1) {
      _pageController.nextPage(duration: Duration(milliseconds: 500), curve: Curves.ease);
      _autoSlideToNext();
    } else {
      _isAutoSliding = false;
    }
  }

  Future<Duration> _getAutoSlideDuration(DocumentSnapshot status) async {
    var data = status.data() as Map<String, dynamic>?;

    if (data != null) {
      String? mediaType = data['mediaType'] as String?;

      if (mediaType == 'video') {
        return _getVideoDuration(data['mediaUrl'] as String);
      } else if (mediaType == 'image') {
        return Duration(seconds: 5); // Adjust the duration for images
      }
    }

    return Duration(seconds: 5); // Default duration for text statuses or unknown media types
  }

  Future<Duration> _getVideoDuration(String videoUrl) async {
    final VideoPlayerController videoController = VideoPlayerController.network(videoUrl);
    await videoController.initialize();
    Duration videoDuration = videoController.value.duration;
    videoController.dispose();
    return videoDuration;
  }

  void _preloadStatuses() {
    for (var status in widget.statuses) {
      var data = status.data() as Map<String, dynamic>?;

      if (data != null) {
        String? mediaType = data['mediaType'] as String?;
        String? mediaUrl = data['mediaUrl'] as String?;

        if (mediaType == 'image') {
          precacheImage(NetworkImage(mediaUrl!), context);
        }
      }
    }
  }

  Future<void> _markStatusAsViewed(DocumentSnapshot status) async {
    if (widget.currentUser == null) return;

    DocumentReference statusRef = FirebaseFirestore.instance
        .collection('status')
        .doc(widget.currentUser!.uid)
        .collection('statuses')
        .doc(status.id);

    try {
      // Fetch current user's name from 'users' collection
      DocumentSnapshot userSnapshot =
      await FirebaseFirestore.instance.collection('users').doc(widget.currentUser!.uid).get();
      String? currentUserName = userSnapshot.get('name');

      // Update viewedById and viewedByName
      await statusRef.update({
        'viewedById': FieldValue.arrayUnion([widget.currentUser!.uid]),
        'viewedByName': FieldValue.arrayUnion([currentUserName ?? '']),
      });
    } catch (e) {
      print("Failed to mark status as viewed: $e");
    }
  }


  void _showViewersDialog(DocumentSnapshot status) {
    User? currentUser = widget.auth.currentUser; // Access auth.currentUser

    if (currentUser == null) {
      // No user signed in, handle accordingly (optional)
      return;
    }

    String currentUserId = currentUser.uid;

    // Check if the current user is the owner of the status
    String statusOwnerId = status.reference.parent.parent!.id; // Get user ID who uploaded the status

    if (currentUserId != statusOwnerId) {
      // If current user is not the owner, do not show the dialog
      return;
    }

    Stream<DocumentSnapshot> statusStream = status.reference.snapshots();

    showDialog(
      context: context,
      builder: (context) => StreamBuilder<DocumentSnapshot>(
        stream: statusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          List<dynamic> viewedByName = snapshot.data?['viewedByName'] ?? [];

          return AlertDialog(
            title: Text('Viewers'),
            content: Container(
              width: double.minPositive,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: viewedByName.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(viewedByName[index]),
                  );
                },
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }


  void _deleteStatus(DocumentSnapshot status) async {
    try {
      await status.reference.delete();
      Navigator.pop(context); // Navigate back to previous screen
    } catch (e) {
      print("Failed to delete status: $e");
    }
  }


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context); // Navigate back to previous screen (StatusUploadPage)
              },
            ),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.remove_red_eye_sharp),
                onPressed: () {
                  _showViewersDialog(widget.statuses[_pageController.page!.round()]);
                },
              ),
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  _deleteStatus(widget.statuses[_pageController.page!.round()]);
                },
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: widget.statuses.length,
            onPageChanged: (index) => _markStatusAsViewed(widget.statuses[index]),
            itemBuilder: (context, index) {
              var status = widget.statuses[index];
              var data = status.data() as Map<String, dynamic>?;




              // Extract status details
              String? mediaUrl = data?['mediaUrl'];
              String? mediaType = data?['mediaType'];
              String? text = data?['text'];
              List<dynamic> likedBy = List.from(data?['likedBy'] ?? []);
              int likeCount = data?['likeCount'] ?? 0;

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('status')
                    .doc(widget.currentUser!.uid)
                    .collection('statuses')
                    .doc(status.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }


                  // Update status data from stream snapshot
                  Map<String, dynamic>? updatedData = snapshot.data?.data() as Map<String, dynamic>?;

                  // Extract updated details
                  List<dynamic> updatedLikedBy = List.from(updatedData?['likedBy'] ?? []);
                  int updatedLikeCount = updatedData?['likeCount'] ?? 0;

                  bool isLiked = updatedLikedBy.contains(widget.currentUser?.uid);

                  return StatusWidget(
                    mediaUrl: mediaUrl,
                    mediaType: mediaType,
                    text: text,
                    isLiked: isLiked,
                    likeCount: updatedLikeCount,
                    onLikePressed: () => _toggleLike(status),
                  );
                },
              );
            },
          ),
        )
    );
  }

  void _toggleLike(DocumentSnapshot status) async {
    if (currentUser == null) return;

    DocumentReference statusRef = FirebaseFirestore.instance
        .collection('status')
        .doc(currentUser!.uid)
        .collection('statuses')
        .doc(status.id);

    // Get current status data
    DocumentSnapshot snapshot = await statusRef.get();
    Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;

    // Check if user already liked the status
    List<dynamic> likedBy = List.from(data?['likedBy'] ?? []);

    if (likedBy.contains(currentUser!.uid)) {
      // User already liked the status, so unlike it
      likedBy.remove(currentUser!.uid);
    } else {
      // User has not liked the status, so like it
      likedBy.add(currentUser!.uid);
    }

    // Update Firestore with new likedBy list and likeCount
    await statusRef.update({
      'likedBy': likedBy,
      'likeCount': likedBy.length,
    });
  }
}



class StatusWidget extends StatelessWidget {
  final String? mediaUrl;
  final String? mediaType;
  final String? text;
  final bool isLiked;
  final int likeCount;
  final VoidCallback onLikePressed;

  const StatusWidget({
    Key? key,
    this.mediaUrl,
    this.mediaType,
    this.text,
    required this.isLiked,
    required this.likeCount,
    required this.onLikePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Content of the status (image, video, or text)
          Center(
            child: mediaType == 'image'
                ? Image.network(
              mediaUrl!,
              fit: BoxFit.contain,
              height: MediaQuery.of(context).size.height * 0.7, // Adjust height as needed
            )
                : mediaType == 'video'
                ? VideoWidget(mediaUrl: mediaUrl!)
                : Text(
              text ?? '',
              style: TextStyle(color: Colors.white),
            ),
          ),

          // Positioned at the top right below the status content
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8.0),
              color: Colors.black.withOpacity(0.5), // Transparent black background
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                    color: isLiked ? Colors.red : Colors.white,
                    onPressed: onLikePressed,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '$likeCount',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}




class VideoWidget extends StatefulWidget {
  final String mediaUrl;

  VideoWidget({required this.mediaUrl});

  @override
  _VideoWidgetState createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.mediaUrl)
      ..initialize().then((_) {
        setState(() {});
        _videoController.play();
      });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _videoController.value.isInitialized
        ? AspectRatio(
      aspectRatio: _videoController.value.aspectRatio,
      child: VideoPlayer(_videoController),
    )
        : Center(child: CircularProgressIndicator());
  }
}
