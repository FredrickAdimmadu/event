import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';


class EventPage extends StatefulWidget {
  @override
  _EventPageState createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _eventsStream;

  @override
  void initState() {
    super.initState();
    _eventsStream = _getEventsStream();
  }

  Stream<QuerySnapshot> _getEventsStream() {
    User? user = _auth.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('events')
          .where('user_id', isEqualTo: user.uid)
          .snapshots();
    } else {
      return Stream.empty();
    }
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

  void _showEventDetails(BuildContext context, DocumentSnapshot eventDoc) async {
    Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;

    // Prepare QR code data
    Map<String, dynamic> qrData = {
      'ticket_id': eventData['ticket_id'],
      'eventName': eventData['eventName'],
      'organizerName': eventData['organizerName'],
      'organizerEmail': eventData['organizerEmail'],
      'eventCountry': eventData['eventCountry'],
      'eventCity': eventData['eventCity'],
      'eventRegion': eventData['eventRegion'],
      'eventPostcode': eventData['eventPostcode'],
      'eventDateTime': eventData['eventDateTime'],
      'eventType': eventData['eventType'],
      'eventCategory': eventData['eventCategory'],
      'eventPaymentType': eventData['eventPaymentType'],
      'price': eventData['price'] ?? '',
    };

    Uint8List qrImage = await _generateQRCode(qrData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(qrImage),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Event Page'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No events found.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((eventDoc) {
              Map<String, dynamic> eventData = eventDoc.data() as Map<String, dynamic>;

              return Card(
                margin: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(eventData['imageUrl'] ?? ''),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.4),
                                BlendMode.darken,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eventData['organizerName'] ?? 'No Name',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  eventData['organizerEmail'] ?? 'No Email',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8.0,
                          top: 8.0,
                          child: IconButton(
                            icon: Icon(Icons.qr_code, color: Colors.white),
                            onPressed: () => _showEventDetails(context, eventDoc),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.location_on),
                                onPressed: () {
                                  _showDetailsDialog(
                                    context,
                                    'Address Details',
                                    '${eventData['eventCountry']}, ${eventData['eventCity']}, ${eventData['eventRegion']}, ${eventData['eventPostcode']}',
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.info),
                                onPressed: () {
                                  _showDetailsDialog(
                                    context,
                                    'Event Name',
                                    eventData['eventName'] ?? 'No Name',
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.category),
                                onPressed: () {
                                  _showDetailsDialog(
                                    context,
                                    'Category',
                                    eventData['eventCategory'] ?? 'No Category',
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.access_time),
                                onPressed: () {
                                  _showDetailsDialog(
                                    context,
                                    'Date & Time',
                                    eventData['eventDateTime'] ?? 'No Date & Time',
                                  );
                                },
                              ),
                              if (eventData['eventPaymentType'] == 'PAID')
                                IconButton(
                                  icon: Icon(Icons.payment),
                                  onPressed: () {
                                    _showDetailsDialog(
                                      context,
                                      'Payment Type',
                                      'Payment Type: ${eventData['eventPaymentType']}\nPrice: ${eventData['price'] ?? 'No Price'}',
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
