import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'homepage.dart'; // Import for date formatting

class EventUploadPage extends StatefulWidget {
  @override
  _EventUploadPageState createState() => _EventUploadPageState();
}

class _EventUploadPageState extends State<EventUploadPage> {
  final _formKey = GlobalKey<FormState>();
  File? _image;
  final picker = ImagePicker();

  String _eventType = 'INDOORS';
  String _eventCategory = 'ENTERTAINMENT';
  String _eventPaymentType = 'FREE';
  String? _price;

  String _eventName = '';
  String _eventCountry = '';
  String _eventCity = '';
  String _eventRegion = '';
  String _eventPostcode = '';
  String _eventDateTime = '';
  String? _userId;
  String _uploadDate = '';
  String _uploadTime = '';
  String? _ticketId;

  bool _isUploading = false; // Initialize _isUploading

  TextEditingController _organizerNameController = TextEditingController();
  TextEditingController _organizerEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrganizerDetails();
  }

  Future<void> _loadOrganizerDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userId = user.uid; // Store user ID
      });

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('social_users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _organizerNameController.text = userDoc['name'] ?? 'No Name Available';
          _organizerEmailController.text = userDoc['email'] ?? 'No Email Available';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<Uint8List> _generateQRCode(Map<String, dynamic> data) async {
    try {
      final qrData = jsonEncode(data); // Convert data map to JSON string
      final qrImage = await QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: false,
        color: Colors.black,
        emptyColor: Colors.white,
      ).toImageData(300);
      return qrImage!.buffer.asUint8List(); // Convert ImageData to Uint8List
    } catch (e) {
      print('Failed to generate QR code: $e');
      return Uint8List(0);
    }
  }

  Future<String> _uploadQRCode(Uint8List qrImage) async {
    if (_userId == null) return '';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('qr_codes')
        .child('$_userId${_ticketId}.png');
    UploadTask uploadTask = storageRef.putData(qrImage);
    TaskSnapshot storageSnapshot = await uploadTask;
    return await storageSnapshot.ref.getDownloadURL();
  }

  Future<void> _uploadEvent() async {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();

      setState(() {
        _isUploading = true;
      });

      try {
        // Capture the current date and time
        DateTime now = DateTime.now();
        _uploadDate = DateFormat('yyyy-MM-dd').format(now);
        _uploadTime = DateFormat('HH:mm').format(now);

        // Generate a random ticket ID
        _ticketId = Uuid().v4();

        // Prepare QR code data
        Map<String, dynamic> qrData = {
          'eventName': _eventName,
          'eventCountry': _eventCountry,
          'eventCity': _eventCity,
          'eventRegion': _eventRegion,
          'eventPostcode': _eventPostcode,
          'eventDateTime': _eventDateTime,
          'eventType': _eventType,
          'eventCategory': _eventCategory,
          'eventPaymentType': _eventPaymentType,
          'price': _price,
          'organizerName': _organizerNameController.text,
          'organizerEmail': _organizerEmailController.text,
          'imageUrl': '', // Placeholder, will be updated after image upload
        };

        // Generate QR code with the data
        Uint8List qrImage = await _generateQRCode(qrData);

        // Upload QR code and get its URL
        String qrCodeUrl = await _uploadQRCode(qrImage);

        // Upload the event image if available and get its URL
        String imageUrl = '';
        if (_image != null && _userId != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('event_images')
              .child('$_userId${DateTime.now().millisecondsSinceEpoch}');
          UploadTask uploadTask = storageRef.putFile(_image!);
          TaskSnapshot storageSnapshot = await uploadTask;
          imageUrl = await storageSnapshot.ref.getDownloadURL();

          // Update QR code data with the image URL
          qrData['imageUrl'] = imageUrl;
          qrImage = await _generateQRCode(qrData);
          qrCodeUrl = await _uploadQRCode(qrImage);
        }

        // Save event details to Firestore
        if (_userId != null) {
          await FirebaseFirestore.instance.collection('events').add({
            'eventName': _eventName,
            'eventCountry': _eventCountry,
            'eventCity': _eventCity,
            'eventRegion': _eventRegion,
            'eventPostcode': _eventPostcode,
            'eventDateTime': _eventDateTime,
            'eventType': _eventType,
            'eventCategory': _eventCategory,
            'eventPaymentType': _eventPaymentType,
            'price': _price,
            'organizerName': _organizerNameController.text,
            'organizerEmail': _organizerEmailController.text,
            'imageUrl': imageUrl,
            'ticket_id': _ticketId,
            'qrCodeUrl': qrCodeUrl,
            'user_id': _userId, // Store the user ID
            'event_upload_date': _uploadDate, // Store the upload date
            'event_upload_time': _uploadTime, // Store the upload time
          });

          _formKey.currentState?.reset();
          setState(() {
            _image = null;
            _eventPaymentType = 'FREE';
            _price = null;
            _ticketId = null;
            _uploadDate = '';
            _uploadTime = '';
            _eventType = 'INDOORS'; // Reset to default value
            _eventCategory = 'ENTERTAINMENT'; // Reset to default value
          });
        }
      } catch (e) {
        print('Failed to upload event: $e');
      }

      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomePage(),
              ),
            );
          },
        ),
        title: Text('Upload Event'),
      ),
      body: _isUploading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: _image == null
                      ? Center(child: Text('Tap to pick an image'))
                      : Image.file(_image!, fit: BoxFit.cover),
                ),
              ),
              SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                value: _eventPaymentType,
                items: ['FREE', 'PAID'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _eventPaymentType = newValue!;
                    _price = null;
                  });
                },
                decoration: InputDecoration(labelText: 'Payment Type'),
              ),
              if (_eventPaymentType == 'PAID')
                TextFormField(
                  decoration: InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _price = value!,
                  validator: (value) =>
                  _eventPaymentType == 'PAID' && value!.isEmpty
                      ? 'Enter price'
                      : null,
                ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Event Name'),
                onSaved: (value) => _eventName = value!,
                validator: (value) =>
                value!.isEmpty ? 'Enter event name' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Event Country'),
                onSaved: (value) => _eventCountry = value!,
                validator: (value) =>
                value!.isEmpty ? 'Enter event country' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Event City'),
                onSaved: (value) => _eventCity = value!,
                validator: (value) =>
                value!.isEmpty ? 'Enter event city' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Event Region'),
                onSaved: (value) => _eventRegion = value!,
                validator: (value) =>
                value!.isEmpty ? 'Enter event region' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Event Postcode'),
                onSaved: (value) => _eventPostcode = value!,
                validator: (value) =>
                value!.isEmpty ? 'Enter event postcode' : null,
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Organizer Name',
                ),
                controller: _organizerNameController,
                readOnly: true,
              ),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Organizer Email',
                ),
                controller: _organizerEmailController,
                readOnly: true,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Event Date & Time'),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        _eventDateTime =
                        '${pickedDate.toLocal()} ${pickedTime.format(context)}';
                      });
                    }
                  }
                },
                controller: TextEditingController(text: _eventDateTime),
              ),
              DropdownButtonFormField<String>(
                value: _eventType,
                items: ['INDOORS', 'OUTDOORS'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _eventType = newValue!;
                  });
                },
                decoration: InputDecoration(labelText: 'Event Type'),
              ),
              DropdownButtonFormField<String>(
                value: _eventCategory,
                items: [
                  'ENTERTAINMENT',
                  'PARTY',
                  'TECHNOLOGY',
                  'ENTREPRENEURSHIP'
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _eventCategory = newValue!;
                  });
                },
                decoration: InputDecoration(labelText: 'Event Category'),
              ),
              SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _uploadEvent,
                child: Text('Upload Event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
