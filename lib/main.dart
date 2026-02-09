import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PokerCasinoApp());
}

// ========== ENUMS ==========
enum Suit { hearts, diamonds, clubs, spades }

enum Rank {
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  ace,
}

enum GameAction { fold, check, call, raise, allIn }

enum BettingRound { preflop, flop, turn, river, showdown }

// ========== DATA MODELS ==========
class CardModel {
  final Suit suit;
  final Rank rank;

  CardModel(this.suit, this.rank);

  String get suitSymbol {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  String get rankText {
    switch (rank) {
      case Rank.ace:
        return 'A';
      case Rank.king:
        return 'K';
      case Rank.queen:
        return 'Q';
      case Rank.jack:
        return 'J';
      default:
        return (rank.index + 2).toString();
    }
  }

  Color get color {
    return (suit == Suit.hearts || suit == Suit.diamonds)
        ? Colors.red
        : Colors.black;
  }

  String get cardName => '$rankText$suitSymbol';

  int get value {
    switch (rank) {
      case Rank.ace:
        return 14;
      case Rank.king:
        return 13;
      case Rank.queen:
        return 12;
      case Rank.jack:
        return 11;
      default:
        return rank.index + 2;
    }
  }

  bool get isFaceCard {
    return rank == Rank.jack || rank == Rank.queen || rank == Rank.king;
  }

  String get faceCardSymbol {
    switch (rank) {
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      default:
        return rankText;
    }
  }

  @override
  String toString() => cardName;
}

class Deck {
  List<CardModel> cards = [];

  Deck() {
    _initializeDeck();
  }

  void _initializeDeck() {
    cards.clear();
    for (var suit in Suit.values) {
      for (var rank in Rank.values) {
        cards.add(CardModel(suit, rank));
      }
    }
  }

  void shuffle() {
    cards.shuffle(Random());
  }

  CardModel drawCard() {
    if (cards.isEmpty) {
      _initializeDeck();
      shuffle();
    }
    return cards.removeLast();
  }

  List<CardModel> drawMultiple(int count) {
    List<CardModel> drawn = [];
    for (int i = 0; i < count; i++) {
      if (cards.isEmpty) {
        _initializeDeck();
        shuffle();
      }
      drawn.add(cards.removeLast());
    }
    return drawn;
  }

  void reset() {
    _initializeDeck();
    shuffle();
  }
}

class PokerHand {
  final List<CardModel> cards;
  String handRank = '';
  int handValue = 0;
  List<int> kickers = [];

  PokerHand(this.cards) {
    _evaluateHand();
  }

  void _evaluateHand() {
    // Sort cards by value descending
    final sortedCards = List<CardModel>.from(cards);
    sortedCards.sort((a, b) => b.value.compareTo(a.value));

    // Check for hand ranks
    if (_isRoyalFlush(sortedCards)) {
      handRank = 'Royal Flush';
      handValue = 10;
      kickers = sortedCards.map((c) => c.value).toList();
    } else if (_isStraightFlush(sortedCards)) {
      handRank = 'Straight Flush';
      handValue = 9;
      kickers = sortedCards.map((c) => c.value).toList();
    } else if (_isFourOfAKind(sortedCards)) {
      handRank = 'Four of a Kind';
      handValue = 8;
      _setKickersForFourOfAKind(sortedCards);
    } else if (_isFullHouse(sortedCards)) {
      handRank = 'Full House';
      handValue = 7;
      _setKickersForFullHouse(sortedCards);
    } else if (_isFlush(sortedCards)) {
      handRank = 'Flush';
      handValue = 6;
      kickers = sortedCards.map((c) => c.value).toList();
    } else if (_isStraight(sortedCards)) {
      handRank = 'Straight';
      handValue = 5;
      kickers = sortedCards.map((c) => c.value).toList();
    } else if (_isThreeOfAKind(sortedCards)) {
      handRank = 'Three of a Kind';
      handValue = 4;
      _setKickersForThreeOfAKind(sortedCards);
    } else if (_isTwoPair(sortedCards)) {
      handRank = 'Two Pair';
      handValue = 3;
      _setKickersForTwoPair(sortedCards);
    } else if (_isOnePair(sortedCards)) {
      handRank = 'One Pair';
      handValue = 2;
      _setKickersForOnePair(sortedCards);
    } else {
      handRank = 'High Card';
      handValue = 1;
      kickers = sortedCards.map((c) => c.value).toList();
    }
  }

  void _setKickersForFourOfAKind(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    int fourValue = valueCount.entries.firstWhere((e) => e.value == 4).key;
    int kicker = valueCount.entries.firstWhere((e) => e.value == 1).key;

    kickers = [fourValue, fourValue, fourValue, fourValue, kicker];
  }

  void _setKickersForFullHouse(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    int threeValue = valueCount.entries.firstWhere((e) => e.value == 3).key;
    int twoValue = valueCount.entries.firstWhere((e) => e.value == 2).key;

    kickers = [threeValue, threeValue, threeValue, twoValue, twoValue];
  }

  void _setKickersForThreeOfAKind(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    int threeValue = valueCount.entries.firstWhere((e) => e.value == 3).key;
    List<int> otherValues = valueCount.entries
        .where((e) => e.value != 3)
        .map((e) => e.key)
        .toList();
    otherValues.sort((a, b) => b.compareTo(a));

    kickers = [threeValue, threeValue, threeValue, ...otherValues.take(2)];
  }

  void _setKickersForTwoPair(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    List<int> pairValues = valueCount.entries
        .where((e) => e.value == 2)
        .map((e) => e.key)
        .toList();
    pairValues.sort((a, b) => b.compareTo(a));

    int kicker = valueCount.entries.firstWhere((e) => e.value == 1).key;

    kickers = [
      pairValues[0],
      pairValues[0],
      pairValues[1],
      pairValues[1],
      kicker,
    ];
  }

  void _setKickersForOnePair(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    int pairValue = valueCount.entries.firstWhere((e) => e.value == 2).key;
    List<int> otherValues = valueCount.entries
        .where((e) => e.value != 2)
        .map((e) => e.key)
        .toList();
    otherValues.sort((a, b) => b.compareTo(a));

    kickers = [pairValue, pairValue, ...otherValues.take(3)];
  }

  bool _isRoyalFlush(List<CardModel> cards) {
    return _isStraightFlush(cards) && cards[0].value == 14;
  }

  bool _isStraightFlush(List<CardModel> cards) {
    return _isFlush(cards) && _isStraight(cards);
  }

  bool _isFourOfAKind(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count == 4);
  }

  bool _isFullHouse(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    final values = valueCount.values.toList();
    return values.contains(3) && values.contains(2);
  }

  bool _isFlush(List<CardModel> cards) {
    final firstSuit = cards[0].suit;
    return cards.every((card) => card.suit == firstSuit);
  }

  bool _isStraight(List<CardModel> cards) {
    // Check for A-2-3-4-5 straight
    if (cards[0].value == 14 &&
        cards[1].value == 5 &&
        cards[2].value == 4 &&
        cards[3].value == 3 &&
        cards[4].value == 2) {
      return true;
    }

    for (int i = 0; i < cards.length - 1; i++) {
      if (cards[i].value != cards[i + 1].value + 1) {
        return false;
      }
    }
    return true;
  }

  bool _isThreeOfAKind(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count == 3);
  }

  bool _isTwoPair(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    final pairs = valueCount.values.where((count) => count == 2).length;
    return pairs == 2;
  }

  bool _isOnePair(List<CardModel> cards) {
    final valueCount = Map<int, int>();
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count == 2);
  }
}

class Player {
  String name;
  List<CardModel> cards = [];
  double chips;
  double currentBet = 0;
  bool isFolded = false;
  bool isAllIn = false;
  bool isActive = true;
  bool isAI;
  String lastAction = '';

  Player({required this.name, required this.chips, this.isAI = false});

  void reset() {
    cards.clear();
    currentBet = 0;
    isFolded = false;
    isAllIn = false;
    isActive = true;
    lastAction = '';
  }

  bool canCheck(double currentBetToMatch) {
    return currentBet >= currentBetToMatch;
  }

  bool canCall(double currentBetToMatch) {
    return chips >= (currentBetToMatch - currentBet);
  }

  bool canRaise(double raiseAmount, double currentBetToMatch) {
    return chips >= (currentBetToMatch - currentBet + raiseAmount);
  }

  void fold() {
    isFolded = true;
    isActive = false;
    lastAction = 'Fold';
  }

  void check() {
    lastAction = 'Check';
  }

  void call(double amount) {
    double amountToCall = amount - currentBet;
    chips -= amountToCall;
    currentBet = amount;
    lastAction = 'Call \$${amountToCall.toStringAsFixed(0)}';
  }

  void raise(double raiseToAmount, double currentBetToMatch) {
    double totalToPut = raiseToAmount - currentBet;
    chips -= totalToPut;
    currentBet = raiseToAmount;
    lastAction = 'Raise to \$${raiseToAmount.toStringAsFixed(0)}';
  }

  void allIn() {
    double totalToPut = chips;
    currentBet += totalToPut;
    chips = 0;
    isAllIn = true;
    lastAction = 'All-In \$${totalToPut.toStringAsFixed(0)}';
  }

  void winPot(double amount) {
    chips += amount;
  }

  PokerHand getBestHand(List<CardModel> communityCards) {
    final allCards = [...cards, ...communityCards];
    return PokerHand(allCards);
  }
}

class PokerGame {
  List<Player> players = [];
  List<CardModel> communityCards = [];
  Deck deck = Deck();
  double pot = 0;
  double currentBet = 0;
  int currentPlayerIndex = 0;
  BettingRound currentRound = BettingRound.preflop;
  bool isGameOver = false;
  Player? winner;
  List<Player> winners = [];
  int smallBlindIndex = 0;
  int bigBlindIndex = 1;
  double smallBlindAmount = 10;
  double bigBlindAmount = 20;
  bool blindsPosted = false;
  int actionsThisRound = 0;

  PokerGame(List<String> playerNames, double startingChips) {
    for (int i = 0; i < playerNames.length; i++) {
      players.add(
        Player(
          name: playerNames[i],
          chips: startingChips,
          isAI: i > 0, // First player is human, others are AI
        ),
      );
    }
    _setupGame();
  }

  void _setupGame() {
    deck.reset();
    communityCards.clear();
    pot = 0;
    currentBet = 0;
    currentRound = BettingRound.preflop;
    isGameOver = false;
    winner = null;
    winners.clear();
    actionsThisRound = 0;

    for (var player in players) {
      player.reset();
    }

    // Post blinds
    _postBlinds();

    // Deal cards
    for (var player in players) {
      player.cards = deck.drawMultiple(2);
    }

    // Set current player (after big blind)
    currentPlayerIndex = (bigBlindIndex + 1) % players.length;
  }

  void _postBlinds() {
    if (!blindsPosted) {
      // Post small blind
      players[smallBlindIndex].chips -= smallBlindAmount;
      players[smallBlindIndex].currentBet = smallBlindAmount;
      players[smallBlindIndex].lastAction = 'Small Blind \$$smallBlindAmount';

      // Post big blind
      players[bigBlindIndex].chips -= bigBlindAmount;
      players[bigBlindIndex].currentBet = bigBlindAmount;
      players[bigBlindIndex].lastAction = 'Big Blind \$$bigBlindAmount';

      pot = smallBlindAmount + bigBlindAmount;
      currentBet = bigBlindAmount;
      blindsPosted = true;
    }
  }

  void nextRound() {
    actionsThisRound = 0;

    switch (currentRound) {
      case BettingRound.preflop:
        currentRound = BettingRound.flop;
        communityCards = deck.drawMultiple(3);
        break;
      case BettingRound.flop:
        currentRound = BettingRound.turn;
        communityCards.add(deck.drawCard());
        break;
      case BettingRound.turn:
        currentRound = BettingRound.river;
        communityCards.add(deck.drawCard());
        break;
      case BettingRound.river:
        currentRound = BettingRound.showdown;
        _determineWinner();
        break;
      case BettingRound.showdown:
        isGameOver = true;
        break;
    }

    // Reset current bets for new round
    for (var player in players) {
      player.currentBet = 0;
    }
    currentBet = 0;

    // Set current player to first active player after dealer
    currentPlayerIndex = smallBlindIndex;
    _moveToNextActivePlayer();
  }

  void _moveToNextActivePlayer() {
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
    } while (!players[currentPlayerIndex].isActive ||
        players[currentPlayerIndex].isFolded ||
        players[currentPlayerIndex].isAllIn);
  }

  bool makeAction(GameAction action, {double? raiseAmount}) {
    final player = players[currentPlayerIndex];

    if (player.isFolded || player.isAllIn) {
      return false;
    }

    switch (action) {
      case GameAction.fold:
        player.fold();
        break;
      case GameAction.check:
        if (player.canCheck(currentBet)) {
          player.check();
        } else {
          return false;
        }
        break;
      case GameAction.call:
        if (player.canCall(currentBet)) {
          double amountToCall = currentBet - player.currentBet;
          pot += amountToCall;
          player.call(currentBet);
        } else {
          // Not enough to call, go all-in
          player.allIn();
          pot += player.currentBet;
        }
        break;
      case GameAction.raise:
        if (raiseAmount != null && player.canRaise(raiseAmount, currentBet)) {
          double oldBet = currentBet;
          currentBet = raiseAmount;
          double amountToRaise = raiseAmount - player.currentBet;
          pot += amountToRaise;
          player.raise(raiseAmount, oldBet);
        } else {
          return false;
        }
        break;
      case GameAction.allIn:
        player.allIn();
        pot += player.currentBet;
        if (player.currentBet > currentBet) {
          currentBet = player.currentBet;
        }
        break;
    }

    actionsThisRound++;
    _moveToNextActivePlayer();

    // Check if betting round is complete
    if (_isBettingRoundComplete()) {
      nextRound();
    }

    return true;
  }

  bool _isBettingRoundComplete() {
    // Check if all players have either folded or matched the current bet
    int activePlayers = 0;
    int playersAtCurrentBet = 0;

    for (var player in players) {
      if (!player.isFolded) {
        activePlayers++;
        if (player.currentBet == currentBet || player.isAllIn) {
          playersAtCurrentBet++;
        }
      }
    }

    // Also need at least one action from each player
    return playersAtCurrentBet == activePlayers &&
        actionsThisRound >= activePlayers;
  }

  void _determineWinner() {
    List<Player> activePlayers = players.where((p) => !p.isFolded).toList();

    if (activePlayers.length == 1) {
      // Only one player left, they win
      winners = [activePlayers.first];
    } else {
      // Compare hands
      List<Map<String, dynamic>> playerHands = [];

      for (var player in activePlayers) {
        final hand = player.getBestHand(communityCards);
        playerHands.add({'player': player, 'hand': hand});
      }

      // Sort by hand strength
      playerHands.sort((a, b) {
        final handA = a['hand'] as PokerHand;
        final handB = b['hand'] as PokerHand;

        if (handA.handValue != handB.handValue) {
          return handB.handValue.compareTo(handA.handValue);
        }

        // Compare kickers
        for (int i = 0; i < handA.kickers.length; i++) {
          if (handA.kickers[i] != handB.kickers[i]) {
            return handB.kickers[i].compareTo(handA.kickers[i]);
          }
        }

        return 0;
      });

      // Get winners (could be split pot)
      final bestHand = playerHands.first['hand'] as PokerHand;
      winners = playerHands
          .where((ph) {
            final hand = ph['hand'] as PokerHand;
            return hand.handValue == bestHand.handValue &&
                ListEquality().equals(hand.kickers, bestHand.kickers);
          })
          .map((ph) => ph['player'] as Player)
          .toList();
    }

    // Award pot to winners
    double amountPerWinner = pot / winners.length;
    for (var winner in winners) {
      winner.winPot(amountPerWinner);
    }

    isGameOver = true;
  }

  void makeAIAction() {
    final player = players[currentPlayerIndex];
    if (!player.isAI || player.isFolded || player.isAllIn) {
      return;
    }

    final random = Random();
    double decision = random.nextDouble();

    // AI decision logic
    if (currentBet == 0) {
      // No bet yet
      if (decision < 0.3) {
        // 30% chance to check
        makeAction(GameAction.check);
      } else if (decision < 0.8) {
        // 50% chance to raise
        double raiseTo =
            currentBet + (random.nextDouble() * 100).roundToDouble();
        makeAction(GameAction.raise, raiseAmount: raiseTo);
      } else {
        // 20% chance to fold (though rarely fold when no bet)
        makeAction(GameAction.fold);
      }
    } else {
      // There's a bet to call
      if (decision < 0.2) {
        // 20% chance to fold
        makeAction(GameAction.fold);
      } else if (decision < 0.6) {
        // 40% chance to call
        makeAction(GameAction.call);
      } else if (decision < 0.9) {
        // 30% chance to raise
        double raiseTo = currentBet * (1.5 + random.nextDouble());
        makeAction(GameAction.raise, raiseAmount: raiseTo);
      } else {
        // 10% chance to go all-in
        makeAction(GameAction.allIn);
      }
    }
  }
}

class ListEquality {
  bool equals(List<int> list1, List<int> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }
}

class User {
  String username;
  String password;
  double balance;
  int points;
  int gamesPlayed;
  int gamesWon;
  DateTime joinDate;
  DateTime? lastLogin;

  User({
    required this.username,
    required this.password,
    this.balance = 1000.0,
    this.points = 0,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    required this.joinDate,
    this.lastLogin,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'balance': balance,
      'points': points,
      'gamesPlayed': gamesPlayed,
      'gamesWon': gamesWon,
      'joinDate': joinDate.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  static User fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      password: json['password'],
      balance: json['balance'].toDouble(),
      points: json['points'],
      gamesPlayed: json['gamesPlayed'],
      gamesWon: json['gamesWon'],
      joinDate: DateTime.parse(json['joinDate']),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
    );
  }

  double get winRate {
    return gamesPlayed > 0 ? (gamesWon / gamesPlayed) * 100 : 0;
  }
}

// ========== DATA MANAGER ==========
class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  final String _usersKey = 'poker_casino_users';
  Map<String, User> _users = {};
  User? _currentUser;

  Future<void> init() async {
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);

    if (usersJson != null) {
      final Map<String, dynamic> usersMap = json.decode(usersJson);
      _users = usersMap.map(
        (key, value) => MapEntry(key, User.fromJson(value)),
      );
    }
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = json.encode(
      _users.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_usersKey, usersJson);
  }

  bool registerUser(String username, String password) {
    if (_users.containsKey(username)) {
      return false;
    }

    if (username.length < 3 || password.length < 4) {
      return false;
    }

    final newUser = User(
      username: username,
      password: password,
      joinDate: DateTime.now(),
    );

    _users[username] = newUser;
    _saveUsers();
    return true;
  }

  bool login(String username, String password) {
    final user = _users[username];
    if (user != null && user.password == password) {
      user.lastLogin = DateTime.now();
      _currentUser = user;
      _saveUsers();
      return true;
    }
    return false;
  }

  void logout() {
    _currentUser = null;
  }

  User? get currentUser => _currentUser;

  Future<void> updateUser(User user) async {
    _users[user.username] = user;
    if (_currentUser?.username == user.username) {
      _currentUser = user;
    }
    await _saveUsers();
  }

  Future<void> addFunds(double amount) async {
    if (_currentUser != null && amount > 0) {
      _currentUser!.balance += amount;
      await updateUser(_currentUser!);
    }
  }
}

// ========== REALISTIC CARD WIDGET ==========
class RealisticPlayingCard extends StatelessWidget {
  final CardModel card;
  final bool isHidden;
  final double width;
  final double height;

  const RealisticPlayingCard({
    super.key,
    required this.card,
    this.isHidden = false,
    this.width = 80,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    if (isHidden) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.blueGrey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: width * 0.8,
            height: height * 0.8,
            decoration: BoxDecoration(
              color: Colors.blueGrey[700],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.white30, width: 1),
            ),
            child: Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: width * 0.3,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Card background with subtle pattern
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Colors.grey[50]!],
              ),
            ),
          ),

          // Top-left rank and suit
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.rankText,
                  style: TextStyle(
                    fontSize: width * 0.2,
                    fontWeight: FontWeight.bold,
                    color: card.color,
                  ),
                ),
                Text(
                  card.suitSymbol,
                  style: TextStyle(fontSize: width * 0.15, color: card.color),
                ),
              ],
            ),
          ),

          // Bottom-right rank and suit (upside down)
          Positioned(
            bottom: 8,
            right: 8,
            child: Transform.rotate(
              angle: pi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.rankText,
                    style: TextStyle(
                      fontSize: width * 0.2,
                      fontWeight: FontWeight.bold,
                      color: card.color,
                    ),
                  ),
                  Text(
                    card.suitSymbol,
                    style: TextStyle(fontSize: width * 0.15, color: card.color),
                  ),
                ],
              ),
            ),
          ),

          // Center large suit symbol (for number cards) or face card
          Center(child: _buildCenterSymbol()),

          // Corner decorations
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomPaint(painter: CardCornerPainter()),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSymbol() {
    if (card.isFaceCard) {
      return Text(
        card.faceCardSymbol,
        style: TextStyle(
          fontSize: width * 0.4,
          fontWeight: FontWeight.bold,
          color: card.color,
        ),
      );
    } else {
      // For number cards, show appropriate number of suit symbols
      return _buildNumberCardSymbols();
    }
  }

  Widget _buildNumberCardSymbols() {
    final int value = card.value;
    List<Widget> symbols = [];

    // Different layouts based on card value
    switch (value) {
      case 2:
        symbols = [
          Positioned(top: 40, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 40, right: 35, child: _buildSuitSymbol()),
        ];
        break;
      case 3:
        symbols = [
          Positioned(top: 30, left: 35, child: _buildSuitSymbol()),
          Positioned(top: 55, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 30, right: 35, child: _buildSuitSymbol()),
        ];
        break;
      case 4:
        symbols = [
          Positioned(top: 30, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 30, right: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 30, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 30, right: 20, child: _buildSuitSymbol()),
        ];
        break;
      case 5:
        symbols = [
          Positioned(top: 30, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 30, right: 20, child: _buildSuitSymbol()),
          Positioned(
            top: height * 0.35,
            left: width * 0.35,
            child: _buildSuitSymbol(),
          ),
          Positioned(bottom: 30, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 30, right: 20, child: _buildSuitSymbol()),
        ];
        break;
      case 6:
        symbols = [
          Positioned(top: 30, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 30, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 55, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 55, right: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 30, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 30, right: 20, child: _buildSuitSymbol()),
        ];
        break;
      case 7:
        symbols = [
          Positioned(top: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 20, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, left: 35, child: _buildSuitSymbol()),
          Positioned(top: 55, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, left: 35, child: _buildSuitSymbol()),
        ];
        break;
      case 8:
        symbols = [
          Positioned(top: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 20, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 55, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, right: 20, child: _buildSuitSymbol()),
        ];
        break;
      case 9:
        symbols = [
          Positioned(top: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 20, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 70, left: 35, child: _buildSuitSymbol()),
          Positioned(top: 55, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 70, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, right: 20, child: _buildSuitSymbol()),
        ];
        break;
      case 10:
        symbols = [
          Positioned(top: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 20, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(top: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(top: 70, left: 35, child: _buildSuitSymbol()),
          Positioned(top: 45, left: 35, child: _buildSuitSymbol()),
          Positioned(top: 45, right: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 70, left: 35, child: _buildSuitSymbol()),
          Positioned(bottom: 45, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 45, right: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, left: 20, child: _buildSuitSymbol()),
          Positioned(bottom: 20, right: 20, child: _buildSuitSymbol()),
        ];
        break;
      default: // Ace
        return Center(
          child: Text(
            'A',
            style: TextStyle(
              fontSize: width * 0.5,
              fontWeight: FontWeight.bold,
              color: card.color,
            ),
          ),
        );
    }

    return Stack(children: symbols);
  }

  Widget _buildSuitSymbol() {
    return Text(
      card.suitSymbol,
      style: TextStyle(fontSize: width * 0.2, color: card.color),
    );
  }
}

class CardCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw rounded corners
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, paint);

    // Draw subtle border
    final innerRect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final innerRrect = RRect.fromRectAndRadius(
      innerRect,
      const Radius.circular(8),
    );
    canvas.drawRRect(innerRrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========== MAIN APP ==========
class PokerCasinoApp extends StatelessWidget {
  const PokerCasinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker Casino',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ========== LOGIN PAGE ==========
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final DataManager _dataManager = DataManager();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _dataManager.init();
  }

  Future<void> _handleAuth() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    bool success = false;
    if (_isLogin) {
      success = _dataManager.login(username, password);
      if (!success) {
        _errorMessage = 'Invalid username or password';
      }
    } else {
      if (username.length < 3) {
        _errorMessage = 'Username must be at least 3 characters';
      } else if (password.length < 4) {
        _errorMessage = 'Password must be at least 4 characters';
      } else {
        success = _dataManager.registerUser(username, password);
        if (!success) {
          _errorMessage = 'Username already exists';
        } else {
          success = _dataManager.login(username, password);
        }
      }
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainMenuPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A5C36), Color(0xFF083022)],
          ),
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            RealisticPlayingCard(
                              card: CardModel(Suit.spades, Rank.ace),
                              width: 40,
                              height: 55,
                            ),
                            const SizedBox(width: 8),
                            RealisticPlayingCard(
                              card: CardModel(Suit.hearts, Rank.ace),
                              width: 40,
                              height: 55,
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'POKER CASINO',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 16),
                            RealisticPlayingCard(
                              card: CardModel(Suit.clubs, Rank.ace),
                              width: 40,
                              height: 55,
                            ),
                            const SizedBox(width: 8),
                            RealisticPlayingCard(
                              card: CardModel(Suit.diamonds, Rank.ace),
                              width: 40,
                              height: 55,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        if (_errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    _isLogin ? 'LOGIN' : 'REGISTER',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _errorMessage = '';
                                  });
                                },
                          child: Text(
                            _isLogin
                                ? 'Don\'t have an account? Register'
                                : 'Already have an account? Login',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========== MAIN MENU PAGE ==========
class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  final DataManager _dataManager = DataManager();

  @override
  Widget build(BuildContext context) {
    final user = _dataManager.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Casino'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A5C36), Color(0xFF083022)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text(
                          'WELCOME',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user?.username ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildInfoCard(
                              'Balance',
                              '\$${user?.balance.toStringAsFixed(2) ?? '0.00'}',
                            ),
                            const SizedBox(width: 16),
                            _buildInfoCard(
                              'Points',
                              user?.points.toString() ?? '0',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildGameCard(
                      'TEXAS HOLD\'EM',
                      'Play real poker with betting',
                      Icons.casino,
                      Colors.blue,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TexasHoldemPage(),
                        ),
                      ),
                    ),
                    _buildGameCard(
                      '1 VS 1',
                      'Heads-up Texas Hold\'em',
                      Icons.person,
                      Colors.purple,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OneVsOnePage(),
                        ),
                      ),
                    ),
                    _buildGameCard(
                      'TOURNAMENT',
                      'Compete for big prizes',
                      Icons.emoji_events,
                      Colors.amber,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TournamentPage(),
                        ),
                      ),
                    ),
                    _buildGameCard(
                      'ADD FUNDS',
                      'Increase your balance',
                      Icons.attach_money,
                      Colors.green,
                      () => _showAddFundsDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _dataManager.logout();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text(
                        'LOGOUT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.3)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFundsDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Funds'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount',
            prefixText: '\$',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                _dataManager.addFunds(amount);
                setState(() {});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '\$${amount.toStringAsFixed(2)} added successfully!',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ========== PROFILE PAGE ==========
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();
    final user = dataManager.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.green,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A5C36), Color(0xFF083022)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.green,
                        radius: 60,
                        child: Text(
                          user.username.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProfileItem('Username', user.username),
                    _buildProfileItem(
                      'Balance',
                      '\$${user.balance.toStringAsFixed(2)}',
                    ),
                    _buildProfileItem('Points', user.points.toString()),
                    _buildProfileItem(
                      'Games Played',
                      user.gamesPlayed.toString(),
                    ),
                    _buildProfileItem('Games Won', user.gamesWon.toString()),
                    _buildProfileItem(
                      'Win Rate',
                      '${user.winRate.toStringAsFixed(1)}%',
                    ),
                    _buildProfileItem('Join Date', _formatDate(user.joinDate)),
                    if (user.lastLogin != null)
                      _buildProfileItem(
                        'Last Login',
                        _formatDateTime(user.lastLogin!),
                      ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          child: Text('BACK TO MENU'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ========== TEXAS HOLD'EM PAGE ==========
class TexasHoldemPage extends StatefulWidget {
  const TexasHoldemPage({super.key});

  @override
  State<TexasHoldemPage> createState() => _TexasHoldemPageState();
}

class _TexasHoldemPageState extends State<TexasHoldemPage> {
  final DataManager _dataManager = DataManager();
  final TextEditingController _buyInController = TextEditingController(
    text: '100',
  );
  PokerGame? _game;
  bool _isGameActive = false;
  double _raiseAmount = 0;
  Player? _humanPlayer;
  String _gameMessage = '';
  bool _showRaiseDialog = false;
  List<String> _actionLog = [];

  @override
  void initState() {
    super.initState();
    _addLog('Welcome to Texas Hold\'em!');
  }

  void _addLog(String message) {
    _actionLog.insert(
      0,
      '${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $message',
    );
    if (_actionLog.length > 10) {
      _actionLog.removeLast();
    }
    setState(() {});
  }

  void _startGame() async {
    final buyIn = double.tryParse(_buyInController.text);
    final user = _dataManager.currentUser;

    if (buyIn == null || buyIn <= 0) {
      _showMessage('Please enter a valid buy-in amount');
      return;
    }

    if (user == null || user.balance < buyIn) {
      _showMessage('Insufficient funds');
      return;
    }

    // Deduct buy-in
    user.balance -= buyIn;
    await _dataManager.updateUser(user);

    // Create game with 6 players (1 human, 5 AI)
    final playerNames = [
      user.username,
      'AI Player 1',
      'AI Player 2',
      'AI Player 3',
      'AI Player 4',
      'AI Player 5',
    ];

    _game = PokerGame(playerNames, buyIn);
    _humanPlayer = _game!.players.firstWhere((p) => !p.isAI);

    _addLog('Game started with \$$buyIn buy-in');
    _addLog('Small Blind: \$${_game!.smallBlindAmount}');
    _addLog('Big Blind: \$${_game!.bigBlindAmount}');

    setState(() {
      _isGameActive = true;
      _gameMessage = 'Game started! Your turn.';
    });

    // Process AI actions until human's turn
    _processAITurns();
  }

  void _processAITurns() {
    if (_game == null || _game!.isGameOver) return;

    // Check if it's AI's turn
    if (_game!.players[_game!.currentPlayerIndex].isAI) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (_game != null && !_game!.isGameOver) {
          final aiPlayer = _game!.players[_game!.currentPlayerIndex];
          _game!.makeAIAction();
          _addLog('${aiPlayer.name}: ${aiPlayer.lastAction}');

          if (!_game!.isGameOver &&
              _game!.players[_game!.currentPlayerIndex].isAI) {
            // Continue processing AI turns
            _processAITurns();
          } else if (_game!.isGameOver) {
            _endGame();
          } else {
            setState(() {
              _gameMessage = 'Your turn. ${_getCurrentBetInfo()}';
            });
          }
        }
      });
    }
  }

  String _getCurrentBetInfo() {
    if (_game == null) return '';
    return 'Current bet: \$${_game!.currentBet.toStringAsFixed(0)} | Pot: \$${_game!.pot.toStringAsFixed(0)}';
  }

  void _makeAction(GameAction action, {double? raiseAmount}) {
    if (_game == null || _game!.isGameOver) return;

    final player = _game!.players[_game!.currentPlayerIndex];
    if (player.isAI) {
      _showMessage('Not your turn!');
      return;
    }

    bool success = _game!.makeAction(action, raiseAmount: raiseAmount);

    if (success) {
      _addLog('${player.name}: ${player.lastAction}');

      if (_game!.isGameOver) {
        _endGame();
      } else {
        // Process AI turns
        _processAITurns();
      }
    } else {
      _showMessage('Invalid action!');
    }

    setState(() {});
  }

  void _endGame() {
    if (_game == null) return;

    final user = _dataManager.currentUser;
    if (user != null && _humanPlayer != null) {
      // Update user balance with chips
      user.balance += _humanPlayer!.chips;
      _dataManager.updateUser(user);

      // Update game stats
      user.gamesPlayed++;
      if (_game!.winners.contains(_humanPlayer)) {
        user.gamesWon++;
        user.points += 10;
      }
      _dataManager.updateUser(user);
    }

    // Show winner message
    if (_game!.winners.isNotEmpty) {
      String winnerNames = _game!.winners.map((w) => w.name).join(', ');
      _gameMessage =
          '🏆 Winners: $winnerNames! \nPot: \$${_game!.pot.toStringAsFixed(0)}';
      _addLog('Game Over! Winners: $winnerNames');
      _addLog('Pot: \$${_game!.pot.toStringAsFixed(0)}');
    }

    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  void _fold() {
    _makeAction(GameAction.fold);
  }

  void _check() {
    _makeAction(GameAction.check);
  }

  void _call() {
    _makeAction(GameAction.call);
  }

  void _raise() {
    showDialog(
      context: context,
      builder: (context) {
        final raiseController = TextEditingController();
        return AlertDialog(
          title: const Text('Enter Raise Amount'),
          content: TextField(
            controller: raiseController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Raise to',
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(raiseController.text);
                if (amount != null && amount > _game!.currentBet) {
                  Navigator.pop(context);
                  _makeAction(GameAction.raise, raiseAmount: amount);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid raise amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Raise'),
            ),
          ],
        );
      },
    );
  }

  void _allIn() {
    _makeAction(GameAction.allIn);
  }

  @override
  Widget build(BuildContext context) {
    final user = _dataManager.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Texas Hold\'em'),
        backgroundColor: Colors.blue,
        actions: [
          if (_isGameActive)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('New Game?'),
                    content: const Text(
                      'Are you sure you want to start a new game? Current game will be forfeited.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _game = null;
                          _isGameActive = false;
                          _gameMessage = '';
                          _actionLog.clear();
                          _addLog('Welcome to Texas Hold\'em!');
                          setState(() {});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('New Game'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          children: [
            // Game Info Bar
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'POT',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '\$${_game?.pot.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'CURRENT BET',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '\$${_game?.currentBet.toStringAsFixed(0) ?? '0'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'ROUND',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          _game?.currentRound
                                  .toString()
                                  .split('.')
                                  .last
                                  .toUpperCase() ??
                              'PREFLOP',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (!_isGameActive) ...[
              // Game Setup
              Expanded(
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'TEXAS HOLD\'EM',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Balance: \$${user?.balance.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _buyInController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Buy-in Amount',
                              prefixText: '\$',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [50, 100, 200, 500].map((amount) {
                              return ElevatedButton(
                                onPressed: () {
                                  _buyInController.text = amount.toString();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[100],
                                  foregroundColor: Colors.blue,
                                ),
                                child: Text('\$$amount'),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'START GAME (6 PLAYERS)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Game in Progress
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Community Cards
                      if (_game?.communityCards.isNotEmpty ?? false)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  _game!.currentRound == BettingRound.showdown
                                      ? 'SHOWDOWN'
                                      : 'COMMUNITY CARDS',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: _game!.communityCards.map((card) {
                                    return RealisticPlayingCard(
                                      card: card,
                                      width: 60,
                                      height: 80,
                                    );
                                  }).toList(),
                                ),
                                if (_game!.currentRound ==
                                    BettingRound.showdown)
                                  const SizedBox(height: 12),
                                if (_game!.currentRound ==
                                    BettingRound.showdown)
                                  Text(
                                    'Showdown! Compare hands',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // Players
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 2.5,
                        padding: const EdgeInsets.all(8),
                        children:
                            _game?.players.asMap().entries.map((entry) {
                              final index = entry.key;
                              final player = entry.value;
                              final isCurrentPlayer =
                                  index == _game!.currentPlayerIndex;
                              final isHuman = !player.isAI;
                              final isFolded = player.isFolded;
                              final isAllIn = player.isAllIn;

                              return Card(
                                margin: const EdgeInsets.all(4),
                                color: isCurrentPlayer
                                    ? Colors.blue[50]
                                    : isHuman
                                    ? Colors.green[50]
                                    : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${player.name}${isHuman ? ' (YOU)' : ''}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isHuman
                                                    ? Colors.green
                                                    : Colors.black,
                                                decoration: isFolded
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          if (isCurrentPlayer)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'TURN',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          if (isAllIn)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                left: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'ALL-IN',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Chips: \$${player.chips.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Bet: \$${player.currentBet.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (player.lastAction.isNotEmpty)
                                        Text(
                                          'Last: ${player.lastAction}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      if (!isFolded)
                                        Row(
                                          children: [
                                            if (player.cards.isNotEmpty)
                                              RealisticPlayingCard(
                                                card: player.cards[0],
                                                isHidden:
                                                    !isHuman &&
                                                    _game!.currentRound !=
                                                        BettingRound.showdown,
                                                width: 30,
                                                height: 40,
                                              ),
                                            const SizedBox(width: 2),
                                            if (player.cards.length > 1)
                                              RealisticPlayingCard(
                                                card: player.cards[1],
                                                isHidden:
                                                    !isHuman &&
                                                    _game!.currentRound !=
                                                        BettingRound.showdown,
                                                width: 30,
                                                height: 40,
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList() ??
                            [],
                      ),

                      // Action Log
                      Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ACTION LOG',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListView.builder(
                                  reverse: true,
                                  itemCount: _actionLog.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        _actionLog[index],
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Game Message
              if (_gameMessage.isNotEmpty)
                Card(
                  margin: const EdgeInsets.all(8),
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _gameMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Action Buttons
              if (_game != null &&
                  !_game!.isGameOver &&
                  !_game!.players[_game!.currentPlayerIndex].isAI)
                Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              'FOLD',
                              Colors.red,
                              Icons.close,
                              _fold,
                              enabled: true,
                            ),
                            _buildActionButton(
                              'CHECK',
                              Colors.blue,
                              Icons.check,
                              _check,
                              enabled:
                                  _humanPlayer?.canCheck(_game!.currentBet) ??
                                  false,
                            ),
                            _buildActionButton(
                              'CALL \$${(_game!.currentBet - (_humanPlayer?.currentBet ?? 0)).toStringAsFixed(0)}',
                              Colors.green,
                              Icons.call_received,
                              _call,
                              enabled:
                                  _humanPlayer?.canCall(_game!.currentBet) ??
                                  false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              'RAISE',
                              Colors.orange,
                              Icons.trending_up,
                              _raise,
                              enabled:
                                  (_humanPlayer?.chips ?? 0) >
                                  _game!.currentBet,
                            ),
                            _buildActionButton(
                              'ALL-IN \$${_humanPlayer?.chips.toStringAsFixed(0) ?? '0'}',
                              Colors.purple,
                              Icons.all_inclusive,
                              _allIn,
                              enabled: (_humanPlayer?.chips ?? 0) > 0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // Game Over Buttons
              if (_game?.isGameOver ?? false)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _game = null;
                            _isGameActive = false;
                            _gameMessage = '';
                            _actionLog.clear();
                            _addLog('Welcome to Texas Hold\'em!');
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('QUIT'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text('PLAY AGAIN'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed, {
    required bool enabled,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ========== 1 VS 1 PAGE ==========
class OneVsOnePage extends StatefulWidget {
  const OneVsOnePage({super.key});

  @override
  State<OneVsOnePage> createState() => _OneVsOnePageState();
}

class _OneVsOnePageState extends State<OneVsOnePage> {
  final DataManager _dataManager = DataManager();
  final TextEditingController _betController = TextEditingController(
    text: '50',
  );
  PokerGame? _game;
  bool _isGameActive = false;
  Player? _humanPlayer;
  String _gameMessage = '';

  void _startGame() async {
    final bet = double.tryParse(_betController.text);
    final user = _dataManager.currentUser;

    if (bet == null || bet <= 0) {
      _showMessage('Please enter a valid bet amount');
      return;
    }

    if (user == null || user.balance < bet) {
      _showMessage('Insufficient funds');
      return;
    }

    // Deduct bet
    user.balance -= bet;
    await _dataManager.updateUser(user);

    // Create 1 vs 1 game
    _game = PokerGame([user.username, 'AI Opponent'], bet);
    _humanPlayer = _game!.players.firstWhere((p) => !p.isAI);

    setState(() {
      _isGameActive = true;
      _gameMessage = 'Game started! Your turn.';
    });

    // Process AI turn if needed
    _processAITurn();
  }

  void _processAITurn() {
    if (_game == null || _game!.isGameOver) return;

    if (_game!.players[_game!.currentPlayerIndex].isAI) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (_game != null && !_game!.isGameOver) {
          _game!.makeAIAction();
          setState(() {});

          if (_game!.isGameOver) {
            _endGame();
          }
        }
      });
    }
  }

  void _makeAction(GameAction action, {double? raiseAmount}) {
    if (_game == null || _game!.isGameOver) return;

    final player = _game!.players[_game!.currentPlayerIndex];
    if (player.isAI) {
      _showMessage('Not your turn!');
      return;
    }

    bool success = _game!.makeAction(action, raiseAmount: raiseAmount);

    if (success) {
      if (_game!.isGameOver) {
        _endGame();
      } else {
        _processAITurn();
      }
    } else {
      _showMessage('Invalid action!');
    }

    setState(() {});
  }

  void _endGame() {
    if (_game == null) return;

    final user = _dataManager.currentUser;
    if (user != null && _humanPlayer != null) {
      user.balance += _humanPlayer!.chips;
      user.gamesPlayed++;

      if (_game!.winners.contains(_humanPlayer)) {
        user.gamesWon++;
        user.points += 5;
      }

      _dataManager.updateUser(user);
    }

    if (_game!.winners.isNotEmpty) {
      String winnerName = _game!.winners.first.name;
      _gameMessage = winnerName == user?.username
          ? '🏆 You win! \$${_game!.pot.toStringAsFixed(0)}'
          : 'AI Opponent wins!';
    }

    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _dataManager.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('1 vs 1 Texas Hold\'em'),
        backgroundColor: Colors.purple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
          ),
        ),
        child: Column(
          children: [
            if (!_isGameActive) ...[
              // Game Setup
              Expanded(
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '1 VS 1 TEXAS HOLD\'EM',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Balance: \$${user?.balance.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _betController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Bet Amount',
                              prefixText: '\$',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            children: [50, 100, 200, 500].map((amount) {
                              return ElevatedButton(
                                onPressed: () {
                                  _betController.text = amount.toString();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[100],
                                  foregroundColor: Colors.purple,
                                ),
                                child: Text('\$$amount'),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'START GAME',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Game in Progress
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Game Info
                      Card(
                        margin: const EdgeInsets.all(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    'POT',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '\$${_game?.pot.toStringAsFixed(0) ?? '0'}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'ROUND',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    _game?.currentRound
                                            .toString()
                                            .split('.')
                                            .last ??
                                        'PREFLOP',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // AI Player
                      Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'AI OPPONENT',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_game != null)
                                Text(
                                  'Chips: \$${_game!.players[1].chips.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_game?.players[1].cards.isNotEmpty ??
                                      false)
                                    RealisticPlayingCard(
                                      card: _game!.players[1].cards[0],
                                      isHidden:
                                          _game?.currentRound !=
                                          BettingRound.showdown,
                                      width: 70,
                                      height: 95,
                                    ),
                                  const SizedBox(width: 8),
                                  if ((_game?.players[1].cards.length ?? 0) > 1)
                                    RealisticPlayingCard(
                                      card: _game!.players[1].cards[1],
                                      isHidden:
                                          _game?.currentRound !=
                                          BettingRound.showdown,
                                      width: 70,
                                      height: 95,
                                    ),
                                ],
                              ),
                              if (_game?.players[1].lastAction.isNotEmpty ??
                                  false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _game!.players[1].lastAction,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Community Cards
                      if (_game?.communityCards.isNotEmpty ?? false)
                        Card(
                          margin: const EdgeInsets.all(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Text(
                                  'COMMUNITY CARDS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: _game!.communityCards.map((card) {
                                    return RealisticPlayingCard(
                                      card: card,
                                      width: 60,
                                      height: 80,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Human Player
                      Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                'YOU',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_humanPlayer != null)
                                Text(
                                  'Chips: \$${_humanPlayer!.chips.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_humanPlayer?.cards.isNotEmpty ?? false)
                                    RealisticPlayingCard(
                                      card: _humanPlayer!.cards[0],
                                      width: 70,
                                      height: 95,
                                    ),
                                  const SizedBox(width: 8),
                                  if ((_humanPlayer?.cards.length ?? 0) > 1)
                                    RealisticPlayingCard(
                                      card: _humanPlayer!.cards[1],
                                      width: 70,
                                      height: 95,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Game Message
                      if (_gameMessage.isNotEmpty)
                        Card(
                          margin: const EdgeInsets.all(8),
                          color: Colors.purple[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _gameMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Action Buttons
                      if (_game != null &&
                          !_game!.isGameOver &&
                          !_game!.players[_game!.currentPlayerIndex].isAI)
                        Card(
                          margin: const EdgeInsets.all(8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildActionButton(
                                      'FOLD',
                                      Colors.red,
                                      Icons.close,
                                      () => _makeAction(GameAction.fold),
                                    ),
                                    _buildActionButton(
                                      'CHECK',
                                      Colors.blue,
                                      Icons.check,
                                      () => _makeAction(GameAction.check),
                                      enabled:
                                          _humanPlayer?.canCheck(
                                            _game!.currentBet,
                                          ) ??
                                          false,
                                    ),
                                    _buildActionButton(
                                      'CALL',
                                      Colors.green,
                                      Icons.call_received,
                                      () => _makeAction(GameAction.call),
                                      enabled:
                                          _humanPlayer?.canCall(
                                            _game!.currentBet,
                                          ) ??
                                          false,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildActionButton(
                                      'RAISE',
                                      Colors.orange,
                                      Icons.trending_up,
                                      () {
                                        // Simple raise for 1vs1
                                        double raiseTo = _game!.currentBet * 2;
                                        _makeAction(
                                          GameAction.raise,
                                          raiseAmount: raiseTo,
                                        );
                                      },
                                      enabled:
                                          (_humanPlayer?.chips ?? 0) >
                                          _game!.currentBet,
                                    ),
                                    _buildActionButton(
                                      'ALL-IN',
                                      Colors.purple,
                                      Icons.all_inclusive,
                                      () => _makeAction(GameAction.allIn),
                                      enabled: (_humanPlayer?.chips ?? 0) > 0,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Game Over Buttons
                      if (_game?.isGameOver ?? false)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _game = null;
                                    _isGameActive = false;
                                    _gameMessage = '';
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(Icons.close),
                                  label: const Text('QUIT'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _startGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('PLAY AGAIN'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ========== TOURNAMENT PAGE ==========
class TournamentPage extends StatefulWidget {
  const TournamentPage({super.key});

  @override
  State<TournamentPage> createState() => _TournamentPageState();
}

class _TournamentPageState extends State<TournamentPage> {
  final DataManager _dataManager = DataManager();
  int? _selectedSize;
  bool _isPlaying = false;
  Map<String, dynamic>? _tournamentResult;
  List<String> _roundResults = [];

  @override
  Widget build(BuildContext context) {
    final user = _dataManager.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Tournament'),
        backgroundColor: Colors.amber,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD97706), Color(0xFF92400E)],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isPlaying) ...[
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                            'POKER TOURNAMENT',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Balance: \$${user?.balance.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Select Tournament Size:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...[
                            {'size': 4, 'fee': 50, 'prize': 200, 'points': 25},
                            {'size': 8, 'fee': 100, 'prize': 800, 'points': 50},
                            {
                              'size': 16,
                              'fee': 200,
                              'prize': 3200,
                              'points': 100,
                            },
                          ].map((tournament) {
                            final size = tournament['size'] as int;
                            final fee = tournament['fee'] as int;
                            final prize = tournament['prize'] as int;
                            final points = tournament['points'] as int;

                            final isSelected = _selectedSize == size;
                            final canAfford = (user?.balance ?? 0) >= fee;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: isSelected
                                  ? Colors.amber[100]
                                  : Colors.white,
                              child: InkWell(
                                onTap: canAfford
                                    ? () => setState(() => _selectedSize = size)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$size-Player Tournament',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: canAfford
                                                    ? Colors.black
                                                    : Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Entry: \$$fee | Prize: \$$prize',
                                              style: TextStyle(
                                                color: canAfford
                                                    ? Colors.grey
                                                    : Colors.red,
                                              ),
                                            ),
                                            Text(
                                              'Points: +$points',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!canAfford)
                                        const Icon(
                                          Icons.money_off,
                                          color: Colors.red,
                                        ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _selectedSize != null
                                  ? _startTournament
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedSize != null
                                    ? Colors.amber
                                    : Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'ENTER TOURNAMENT',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    height: 500,
                    child: Column(
                      children: [
                        if (_tournamentResult == null) ...[
                          const Text(
                            'TOURNAMENT IN PROGRESS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _roundResults.length,
                              itemBuilder: (context, index) {
                                final roundResult = _roundResults[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.amber,
                                      child: Text('${index + 1}'),
                                    ),
                                    title: Text('Round ${index + 1}'),
                                    subtitle: Text(roundResult),
                                    trailing: const Icon(Icons.arrow_forward),
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else ...[
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _tournamentResult!['won']
                                        ? Icons.emoji_events
                                        : Icons.sports,
                                    size: 80,
                                    color: _tournamentResult!['won']
                                        ? Colors.amber
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _tournamentResult!['won']
                                        ? '🏆 VICTORY! 🏆'
                                        : 'TOURNAMENT ENDED',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: _tournamentResult!['won']
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Position: ${_getOrdinal(_tournamentResult!['position'])}',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  if (_tournamentResult!['amount'] > 0) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Prize: \$${_tournamentResult!['amount'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                  if (_tournamentResult!['points'] > 0) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Points: +${_tournamentResult!['points']}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _tournamentResult != null
                          ? _finishTournament
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tournamentResult != null
                            ? Colors.green
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _tournamentResult != null
                            ? 'BACK TO MENU'
                            : 'PLAYING...',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  void _startTournament() async {
    final user = _dataManager.currentUser;
    if (user == null || _selectedSize == null) return;

    final entryFee = _selectedSize == 4
        ? 50
        : _selectedSize == 8
        ? 100
        : 200;

    if (user.balance < entryFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Need \$$entryFee to enter tournament'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Deduct entry fee
    user.balance -= entryFee;
    await _dataManager.updateUser(user);

    setState(() {
      _isPlaying = true;
      _tournamentResult = null;
      _roundResults = [];
    });

    // Simulate rounds
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _roundResults.add('Round $i completed');
      });
    }

    await Future.delayed(const Duration(seconds: 1));

    // Simple tournament simulation
    final random = Random();
    final position = random.nextInt(_selectedSize!) + 1;
    final won = position == 1;

    double prize = 0;
    int points = 0;

    if (position == 1) {
      prize = entryFee * _selectedSize! * 0.6;
      points = _selectedSize == 16
          ? 100
          : _selectedSize == 8
          ? 50
          : 25;
    } else if (position == 2) {
      prize = entryFee * _selectedSize! * 0.3;
      points = _selectedSize == 16
          ? 50
          : _selectedSize == 8
          ? 25
          : 10;
    } else if (position == 3) {
      prize = entryFee * _selectedSize! * 0.1;
      points = _selectedSize == 16 ? 25 : 10;
    } else {
      points = 5;
    }

    // Update user
    if (won) {
      user.balance += prize;
      user.gamesWon++;
      user.points += points;
    } else if (position <= 3) {
      user.balance += prize;
      user.points += points;
    } else {
      user.points += points;
    }

    user.gamesPlayed++;
    await _dataManager.updateUser(user);

    setState(() {
      _tournamentResult = {
        'won': won,
        'position': position,
        'amount': prize,
        'points': points,
      };
    });
  }

  void _finishTournament() {
    Navigator.pop(context);
  }
}
