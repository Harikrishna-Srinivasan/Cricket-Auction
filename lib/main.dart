// cricket_auction_app.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Champions Trophy Auction',
      home: AuctionHomePage(),
    );
  }
}

class Player {
  final String name;
  final String? country;
  final String? flagUrl;
  int? bidAmount;

  Player({required this.name, this.country, this.flagUrl, this.bidAmount});

  factory Player.fromJson(Map<String, dynamic> json, Map<String, String> countryFlags) {
    return Player(
      name: json['name'],
      country: json['country'],
      flagUrl: countryFlags[json['country']] ?? 'assets/placeholder.png',
    );
  }
}

class AuctionHomePage extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _AuctionHomePageState createState() => _AuctionHomePageState();
}

class _AuctionHomePageState extends State<AuctionHomePage> {
  Future<List<Player>>? playersFuture;
  int totalBudget = 0;
  int remainingBudget = 0;
  int playersTaken = 0;

  @override
  void initState() {
    super.initState();
    playersFuture = fetchPlayersWithFlags();
    promptUserForBudget();
  }

  void promptUserForBudget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) {
          int? enteredAmount;
          return AlertDialog(
            title: Text('Enter Total Budget'),
            content: TextField(
              keyboardType: TextInputType.number,
              onChanged: (value) {
                enteredAmount = int.tryParse(value);
              },
              decoration: InputDecoration(hintText: 'Enter your total budget'),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  if (enteredAmount! > 0) {
                    setState(() {
                      totalBudget = enteredAmount!;
                      remainingBudget = enteredAmount!;
                    });
                    Navigator.pop(context);
                  }
                },
                child: Text('Set Budget'),
              ),
            ],
          );
        },
      );
    });
  }

  Future<Map<String, String>> fetchCountryFlags() async {
    final response = await http.get(Uri.parse('https://api.cricapi.com/v1/countries?apikey=${dotenv.env['API_KEY']}'));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['status'] == 'success') {
        return {for (var country in jsonData['data']) country['name']: country['genericFlag']};
      } else {
        return {"reason": jsonData['reason']};
      }
    }
    return {};
  }

  Future<List<Player>> fetchPlayersWithFlags() async {
    final flags = await fetchCountryFlags();
    final response = await http.get(Uri.parse('https://api.cricapi.com/v1/players?apikey=${dotenv.env['API_KEY']}'));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData['status'] == 'success') {
        List<dynamic> playersData = jsonData['data'];
        return playersData.map((json) => Player.fromJson(json, flags)).toList();
      }
    }
    return [];
  }

  void placeBid(Player player) {
    if (playersTaken >= 11 || remainingBudget <= 0) return;
    int? bidAmount;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Place Bid for ${player.name}'),
          content: TextField(
            keyboardType: TextInputType.number,
            onChanged: (value) {
              bidAmount = int.tryParse(value);
            },
            decoration: InputDecoration(hintText: 'Enter bid amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (bidAmount != null && bidAmount! <= remainingBudget) {
                  setState(() {
                    player.bidAmount = bidAmount;
                    remainingBudget -= bidAmount!;
                    playersTaken++;
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Place Bid'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Champions Trophy Auction'),
      ),
      body: FutureBuilder<List<Player>>(
        future: playersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No players found.'));
          } else {
            final players = snapshot.data!;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(player.flagUrl ?? 'assets/placeholder.png'),
                      ),
                      SizedBox(height: 10),
                      Text(player.name, textAlign: TextAlign.center),
                      Text(player.country ?? 'Unknown Country'),
                      Text(player.bidAmount != null ? 'Bid: Rs.${player.bidAmount}' : 'No Bid'),
                      ElevatedButton(
                        onPressed: (playersTaken < 11 && remainingBudget > 0) ? () => placeBid(player) : null,
                        child: Text('Bid'),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
