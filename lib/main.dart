import 'dart:async';
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
    final bestFive = _getBestFiveCardHand();
    final sortedCards = List<CardModel>.from(bestFive);
    sortedCards.sort((a, b) => b.value.compareTo(a.value));

    if (_isRoyalFlush(sortedCards)) {
      handRank = 'Royal Flush';
      handValue = 10;
      kickers = sortedCards.map((c) => c.value).toList();
    } else if (_isStraightFlush(sortedCards)) {
      handRank = 'Straight Flush';
      handValue = 9;
      kickers = [sortedCards[0].value];
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
      kickers = [sortedCards[0].value];
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

  List<CardModel> _getBestFiveCardHand() {
    if (cards.length <= 5) return cards;

    List<List<CardModel>> combinations = [];
    _generateCombinations(cards, 5, 0, [], combinations);

    combinations.sort((a, b) {
      final handA = PokerHand(a);
      final handB = PokerHand(b);
      return _compareHands(handB, handA);
    });

    return combinations.isNotEmpty ? combinations.first : cards.sublist(0, 5);
  }

  void _generateCombinations(
    List<CardModel> cards,
    int k,
    int start,
    List<CardModel> current,
    List<List<CardModel>> result,
  ) {
    if (current.length == k) {
      result.add(List.from(current));
      return;
    }

    for (int i = start; i < cards.length; i++) {
      current.add(cards[i]);
      _generateCombinations(cards, k, i + 1, current, result);
      current.removeLast();
    }
  }

  int _compareHands(PokerHand handA, PokerHand handB) {
    if (handA.handValue != handB.handValue) {
      return handA.handValue.compareTo(handB.handValue);
    }

    for (int i = 0; i < handA.kickers.length; i++) {
      if (handA.kickers[i] != handB.kickers[i]) {
        return handA.kickers[i].compareTo(handB.kickers[i]);
      }
    }

    return 0;
  }

  void _setKickersForFourOfAKind(List<CardModel> cards) {
    final valueCount = <int, int>{};
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    int fourValue = valueCount.entries.firstWhere((e) => e.value == 4).key;
    int kicker = valueCount.entries.firstWhere((e) => e.value == 1).key;

    kickers = [fourValue, fourValue, fourValue, fourValue, kicker];
  }

  void _setKickersForFullHouse(List<CardModel> cards) {
    final valueCount = <int, int>{};
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }

    int threeValue = valueCount.entries.firstWhere((e) => e.value == 3).key;
    int twoValue = valueCount.entries.firstWhere((e) => e.value == 2).key;

    kickers = [threeValue, threeValue, threeValue, twoValue, twoValue];
  }

  void _setKickersForThreeOfAKind(List<CardModel> cards) {
    final valueCount = <int, int>{};
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
    final valueCount = <int, int>{};
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
    final valueCount = <int, int>{};
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
    final valueCount = <int, int>{};
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count == 4);
  }

  bool _isFullHouse(List<CardModel> cards) {
    final valueCount = <int, int>{};
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
    final values = cards.map((c) => c.value).toSet().toList();
    if (values.length < 5) return false;
    values.sort((a, b) => b.compareTo(a));

    // Check for A-2-3-4-5 straight (wheel)
    if (values.contains(14) &&
        values.contains(5) &&
        values.contains(4) &&
        values.contains(3) &&
        values.contains(2)) {
      return true;
    }

    // Check for normal straight
    for (int i = 0; i <= values.length - 5; i++) {
      bool isStraight = true;
      for (int j = i; j < i + 4; j++) {
        if (values[j] != values[j + 1] + 1) {
          isStraight = false;
          break;
        }
      }
      if (isStraight) return true;
    }
    return false;
  }

  bool _isThreeOfAKind(List<CardModel> cards) {
    final valueCount = <int, int>{};
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    return valueCount.values.any((count) => count == 3);
  }

  bool _isTwoPair(List<CardModel> cards) {
    final valueCount = <int, int>{};
    for (var card in cards) {
      valueCount[card.value] = (valueCount[card.value] ?? 0) + 1;
    }
    final pairs = valueCount.values.where((count) => count == 2).length;
    return pairs == 2;
  }

  bool _isOnePair(List<CardModel> cards) {
    final valueCount = <int, int>{};
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
    if (amountToCall > chips) {
      amountToCall = chips;
    }
    chips -= amountToCall;
    currentBet = amount;
    lastAction = 'Call \$${amountToCall.toStringAsFixed(0)}';
  }

  void raise(double raiseToAmount, double currentBetToMatch) {
    double totalToPut = raiseToAmount - currentBet;
    if (totalToPut > chips) {
      totalToPut = chips;
    }
    chips -= totalToPut;
    currentBet = raiseToAmount;
    lastAction = 'Raise to \$${raiseToAmount.toStringAsFixed(0)}';
  }

  void allIn() {
    double allInAmount = chips;
    currentBet += allInAmount;
    chips = 0;
    isAllIn = true;
    lastAction = 'All-In \$${allInAmount.toStringAsFixed(0)}';
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
  int dealerIndex = 0;
  int numPlayers = 9;

  PokerGame(
    List<String> playerNames,
    double startingChips, {
    this.numPlayers = 9,
  }) {
    for (int i = 0; i < min(playerNames.length, numPlayers); i++) {
      players.add(
        Player(name: playerNames[i], chips: startingChips, isAI: i > 0),
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
    blindsPosted = false;

    for (var player in players) {
      player.reset();
    }

    dealerIndex = (dealerIndex + 1) % players.length;
    smallBlindIndex = (dealerIndex + 1) % players.length;
    bigBlindIndex = (dealerIndex + 2) % players.length;

    _postBlinds();

    for (var player in players) {
      player.cards = deck.drawMultiple(2);
    }

    currentPlayerIndex = (bigBlindIndex + 1) % players.length;
    _moveToNextActivePlayerIfNeeded();
  }

  void _postBlinds() {
    if (!blindsPosted) {
      players[smallBlindIndex].chips -= smallBlindAmount;
      players[smallBlindIndex].currentBet = smallBlindAmount;
      players[smallBlindIndex].lastAction = 'Small Blind \$$smallBlindAmount';

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

    for (var player in players) {
      player.currentBet = 0;
    }
    currentBet = 0;

    currentPlayerIndex = smallBlindIndex;
    _moveToNextActivePlayer();
  }

  void _moveToNextActivePlayer() {
    int startIndex = currentPlayerIndex;
    do {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      if (currentPlayerIndex == startIndex) {
        break;
      }
    } while (!players[currentPlayerIndex].isActive ||
        players[currentPlayerIndex].isFolded ||
        players[currentPlayerIndex].isAllIn);
  }

  void _moveToNextActivePlayerIfNeeded() {
    if (!players[currentPlayerIndex].isActive ||
        players[currentPlayerIndex].isFolded ||
        players[currentPlayerIndex].isAllIn) {
      _moveToNextActivePlayer();
    }
  }

  bool makeAction(GameAction action, {double? raiseAmount}) {
    final player = players[currentPlayerIndex];

    if (player.isFolded || player.isAllIn || !player.isActive) {
      return false;
    }

    bool actionSuccess = false;
    double actionAmount = 0;

    switch (action) {
      case GameAction.fold:
        player.fold();
        actionSuccess = true;
        break;
      case GameAction.check:
        if (player.canCheck(currentBet)) {
          player.check();
          actionSuccess = true;
        }
        break;
      case GameAction.call:
        double amountToCall = currentBet - player.currentBet;
        if (amountToCall <= 0) {
          // Can check instead
          player.check();
          actionSuccess = true;
        } else if (player.chips >= amountToCall) {
          // Normal call
          actionAmount = amountToCall;
          player.chips -= actionAmount;
          player.currentBet += actionAmount;
          pot += actionAmount;
          player.lastAction = 'Call \$${actionAmount.toStringAsFixed(0)}';
          actionSuccess = true;
        } else {
          // All-in call
          actionAmount = player.chips;
          player.currentBet += actionAmount;
          pot += actionAmount;
          player.chips = 0;
          player.isAllIn = true;
          player.lastAction = 'All-In \$${actionAmount.toStringAsFixed(0)}';
          actionSuccess = true;
        }
        break;
      case GameAction.raise:
        if (raiseAmount != null &&
            raiseAmount > currentBet &&
            player.canRaise(raiseAmount, currentBet)) {
          double oldBet = currentBet;
          double amountToRaise = raiseAmount - player.currentBet;

          if (player.chips >= amountToRaise) {
            // Normal raise
            currentBet = raiseAmount;
            actionAmount = amountToRaise;
            player.chips -= actionAmount;
            player.currentBet = raiseAmount;
            pot += actionAmount;
            player.lastAction = 'Raise to \$${raiseAmount.toStringAsFixed(0)}';
            actionSuccess = true;
          } else {
            // All-in raise (can't cover full raise)
            actionAmount = player.chips;
            player.currentBet += actionAmount;
            pot += actionAmount;
            player.chips = 0;
            player.isAllIn = true;
            currentBet = player.currentBet;
            player.lastAction = 'All-In \$${actionAmount.toStringAsFixed(0)}';
            actionSuccess = true;
          }
        }
        break;
      case GameAction.allIn:
        actionAmount = player.chips;
        if (actionAmount > 0) {
          player.currentBet += actionAmount;
          pot += actionAmount;

          // Update currentBet if all-in creates a new bet level
          if (player.currentBet > currentBet) {
            currentBet = player.currentBet;
          }

          player.chips = 0;
          player.isAllIn = true;
          player.lastAction = 'All-In \$${actionAmount.toStringAsFixed(0)}';
          actionSuccess = true;
        }
        break;
    }

    if (actionSuccess) {
      actionsThisRound++;
      _moveToNextActivePlayer();

      // Check if all active players are all-in
      if (_areAllActivePlayersAllIn) {
        // If all active players are all-in, deal remaining cards immediately
        _dealRemainingCardsForAllIn();
      } else if (_isBettingRoundComplete()) {
        nextRound();
      }
    }

    return actionSuccess;
  }

  void _dealRemainingCardsForAllIn() {
    // Deal remaining community cards when all active players are all-in
    while (currentRound != BettingRound.showdown) {
      switch (currentRound) {
        case BettingRound.preflop:
          // Deal flop
          if (communityCards.isEmpty) {
            communityCards = deck.drawMultiple(3);
          }
          currentRound = BettingRound.flop;
          break;
        case BettingRound.flop:
          // Deal turn
          if (communityCards.length < 4) {
            communityCards.add(deck.drawCard());
          }
          currentRound = BettingRound.turn;
          break;
        case BettingRound.turn:
          // Deal river
          if (communityCards.length < 5) {
            communityCards.add(deck.drawCard());
          }
          currentRound = BettingRound.river;
          break;
        case BettingRound.river:
          currentRound = BettingRound.showdown;
          break;
        case BettingRound.showdown:
          break;
      }
    }

    // Determine winner immediately
    _determineWinner();
  }

  bool _isBettingRoundComplete() {
    List<Player> activeNonAllInPlayers = players
        .where((p) => !p.isFolded && !p.isAllIn)
        .toList();

    // If all active players are all-in, betting round is complete
    if (activeNonAllInPlayers.isEmpty) {
      return true;
    }

    // Check if all active non-all-in players have matched the current bet
    bool allBetsMatched = true;
    for (var player in activeNonAllInPlayers) {
      if (player.currentBet < currentBet) {
        allBetsMatched = false;
        break;
      }
    }

    // Also need at least one complete cycle of actions
    return allBetsMatched && actionsThisRound >= activeNonAllInPlayers.length;
  }

  bool get _areAllActivePlayersAllIn {
    List<Player> activePlayers = players.where((p) => !p.isFolded).toList();
    if (activePlayers.isEmpty) return false;
    return activePlayers.every((p) => p.isAllIn);
  }

  void _determineWinner() {
    List<Player> activePlayers = players.where((p) => !p.isFolded).toList();

    if (activePlayers.isEmpty) {
      winners = [];
      return;
    }

    if (activePlayers.length == 1) {
      winners = [activePlayers.first];
    } else {
      List<Map<String, dynamic>> playerHands = [];

      for (var player in activePlayers) {
        final hand = player.getBestHand(communityCards);
        playerHands.add({'player': player, 'hand': hand});
      }

      playerHands.sort((a, b) {
        final handA = a['hand'] as PokerHand;
        final handB = b['hand'] as PokerHand;

        if (handA.handValue != handB.handValue) {
          return handB.handValue.compareTo(handA.handValue);
        }

        for (
          int i = 0;
          i < min(handA.kickers.length, handB.kickers.length);
          i++
        ) {
          if (handA.kickers[i] != handB.kickers[i]) {
            return handB.kickers[i].compareTo(handA.kickers[i]);
          }
        }

        return 0;
      });

      final bestHand = playerHands.first['hand'] as PokerHand;
      winners = playerHands
          .where((ph) {
            final hand = ph['hand'] as PokerHand;
            if (hand.handValue != bestHand.handValue) return false;

            for (
              int i = 0;
              i < min(hand.kickers.length, bestHand.kickers.length);
              i++
            ) {
              if (hand.kickers[i] != bestHand.kickers[i]) return false;
            }
            return true;
          })
          .map((ph) => ph['player'] as Player)
          .toList();
    }

    if (winners.isNotEmpty) {
      double amountPerWinner = pot / winners.length;
      for (var winner in winners) {
        winner.winPot(amountPerWinner);
      }
    }

    isGameOver = true;
  }

  bool get areAllActivePlayersAllIn {
    List<Player> activePlayers = players.where((p) => !p.isFolded).toList();
    if (activePlayers.length <= 1) return false;
    return activePlayers.every((p) => p.isAllIn);
  }

  void makeAIAction() {
    final player = players[currentPlayerIndex];
    if (!player.isAI || player.isFolded || player.isAllIn) {
      return;
    }

    final random = Random();
    double decision = random.nextDouble();

    if (currentBet == 0) {
      if (decision < 0.4) {
        makeAction(GameAction.check);
      } else if (decision < 0.9) {
        double raiseTo =
            currentBet + (random.nextDouble() * 50 + 20).roundToDouble();
        makeAction(GameAction.raise, raiseAmount: raiseTo);
      } else {
        makeAction(GameAction.fold);
      }
    } else {
      double callAmount = currentBet - player.currentBet;
      double potOdds = callAmount / (pot + callAmount);

      if (decision < potOdds * 0.3) {
        makeAction(GameAction.fold);
      } else if (decision < 0.6) {
        makeAction(GameAction.call);
      } else if (decision < 0.9 && player.chips > currentBet * 2) {
        double raiseTo = currentBet * (1.5 + random.nextDouble());
        makeAction(GameAction.raise, raiseAmount: raiseTo);
      } else {
        if (player.chips <= callAmount * 3) {
          makeAction(GameAction.allIn);
        } else {
          makeAction(GameAction.call);
        }
      }
    }
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

// ========== ANIMATED CARD WIDGET ==========
class RealisticPlayingCard extends StatefulWidget {
  final CardModel card;
  final bool isHidden;
  final double width;
  final double height;
  final bool dealAnimation;
  final Duration animationDelay;
  final bool flipAnimation;

  const RealisticPlayingCard({
    super.key,
    required this.card,
    this.isHidden = false,
    this.width = 80,
    this.height = 110,
    this.dealAnimation = false,
    this.animationDelay = Duration.zero,
    this.flipAnimation = false,
  });

  @override
  State<RealisticPlayingCard> createState() => _RealisticPlayingCardState();
}

class _RealisticPlayingCardState extends State<RealisticPlayingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    if (widget.dealAnimation || widget.flipAnimation) {
      Future.delayed(widget.animationDelay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      ),
      child: widget.isHidden ? _buildCardBack() : _buildCardFaceUp(),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: widget.width * 0.8,
          height: widget.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.blueGrey[700],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30, width: 1),
          ),
          child: Center(
            child: Text(
              '?',
              style: TextStyle(
                fontSize: widget.width * 0.3,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFaceUp() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
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

          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.card.rankText,
                  style: TextStyle(
                    fontSize: widget.width * 0.2,
                    fontWeight: FontWeight.bold,
                    color: widget.card.color,
                  ),
                ),
                Text(
                  widget.card.suitSymbol,
                  style: TextStyle(
                    fontSize: widget.width * 0.15,
                    color: widget.card.color,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 8,
            right: 8,
            child: Transform.rotate(
              angle: pi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.card.rankText,
                    style: TextStyle(
                      fontSize: widget.width * 0.2,
                      fontWeight: FontWeight.bold,
                      color: widget.card.color,
                    ),
                  ),
                  Text(
                    widget.card.suitSymbol,
                    style: TextStyle(
                      fontSize: widget.width * 0.15,
                      color: widget.card.color,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Center(child: _buildCenterSymbol()),
        ],
      ),
    );
  }

  Widget _buildCenterSymbol() {
    if (widget.card.isFaceCard) {
      return Text(
        widget.card.faceCardSymbol,
        style: TextStyle(
          fontSize: widget.width * 0.4,
          fontWeight: FontWeight.bold,
          color: widget.card.color,
        ),
      );
    } else {
      return _buildNumberCardSymbols();
    }
  }

  Widget _buildNumberCardSymbols() {
    final int value = widget.card.value;
    List<Widget> symbols = [];

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
            top: widget.height * 0.35,
            left: widget.width * 0.35,
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
      default:
        return Center(
          child: Text(
            'A',
            style: TextStyle(
              fontSize: widget.width * 0.5,
              fontWeight: FontWeight.bold,
              color: widget.card.color,
            ),
          ),
        );
    }

    return Stack(children: symbols);
  }

  Widget _buildSuitSymbol() {
    return Text(
      widget.card.suitSymbol,
      style: TextStyle(fontSize: widget.width * 0.2, color: widget.card.color),
    );
  }
}

// ========== ACTION SELECTION DIALOG ==========
class ActionSelectionDialog extends StatefulWidget {
  final Function(GameAction, double?) onActionSelected;
  final double currentBet;
  final double playerCurrentBet;
  final double playerChips;
  final bool canCheck;
  final bool canCall;
  final bool canRaise;

  const ActionSelectionDialog({
    super.key,
    required this.onActionSelected,
    required this.currentBet,
    required this.playerCurrentBet,
    required this.playerChips,
    required this.canCheck,
    required this.canCall,
    required this.canRaise,
  });

  @override
  State<ActionSelectionDialog> createState() => _ActionSelectionDialogState();
}

class _ActionSelectionDialogState extends State<ActionSelectionDialog> {
  bool _showRaiseOptions = false;
  final TextEditingController _raiseController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'YOUR TURN',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Current Bet: \$${widget.currentBet.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Your Chips: \$${widget.playerChips.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),

            if (!_showRaiseOptions) ...[
              _buildActionButton(
                'FOLD',
                Colors.red,
                Icons.close,
                () => widget.onActionSelected(GameAction.fold, null),
              ),
              const SizedBox(height: 10),

              if (widget.canCheck)
                _buildActionButton(
                  'CHECK',
                  Colors.blue,
                  Icons.check,
                  () => widget.onActionSelected(GameAction.check, null),
                ),

              if (widget.canCall && !widget.canCheck)
                _buildActionButton(
                  'CALL \$${(widget.currentBet - widget.playerCurrentBet).toStringAsFixed(0)}',
                  Colors.green,
                  Icons.call_received,
                  () => widget.onActionSelected(GameAction.call, null),
                ),

              const SizedBox(height: 10),

              if (widget.canRaise)
                _buildActionButton(
                  'RAISE',
                  Colors.orange,
                  Icons.trending_up,
                  () => setState(() {
                    _raiseController.text = (widget.currentBet * 2)
                        .toStringAsFixed(0);
                    _showRaiseOptions = true;
                  }),
                ),

              const SizedBox(height: 10),

              _buildActionButton(
                'ALL-IN \$${widget.playerChips.toStringAsFixed(0)}',
                Colors.purple,
                Icons.all_inclusive,
                () => widget.onActionSelected(GameAction.allIn, null),
              ),
            ] else ...[
              Text(
                'ENTER RAISE AMOUNT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _raiseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Raise to',
                  prefixText: '\$',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText:
                      'Minimum: \$${(widget.currentBet * 2).toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => _showRaiseOptions = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('BACK'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(_raiseController.text);
                      if (amount != null &&
                          amount >= widget.currentBet * 2 &&
                          amount <=
                              widget.playerChips + widget.playerCurrentBet) {
                        Navigator.pop(context);
                        widget.onActionSelected(GameAction.raise, amount);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid raise amount'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('RAISE'),
                  ),
                ],
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
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ========== MINI ACTION PANEL ==========
class MiniActionPanel extends StatefulWidget {
  final Function(GameAction, double?) onActionSelected;
  final double currentBet;
  final double playerCurrentBet;
  final double playerChips;
  final bool canCheck;
  final bool canCall;
  final bool canRaise;
  final Duration autoFoldDuration;
  final Function() onAutoFold;

  const MiniActionPanel({
    super.key,
    required this.onActionSelected,
    required this.currentBet,
    required this.playerCurrentBet,
    required this.playerChips,
    required this.canCheck,
    required this.canCall,
    required this.canRaise,
    this.autoFoldDuration = const Duration(seconds: 15),
    required this.onAutoFold,
  });

  @override
  State<MiniActionPanel> createState() => _MiniActionPanelState();
}

class _MiniActionPanelState extends State<MiniActionPanel> {
  late Timer _autoFoldTimer;
  int _secondsRemaining = 15;

  @override
  void initState() {
    super.initState();
    _startAutoFoldTimer();
  }

  void _startAutoFoldTimer() {
    _secondsRemaining = widget.autoFoldDuration.inSeconds;
    _autoFoldTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        widget.onAutoFold();
      }
    });
  }

  void _resetTimer() {
    _autoFoldTimer.cancel();
    _startAutoFoldTimer();
  }

  @override
  void dispose() {
    _autoFoldTimer.cancel();
    super.dispose();
  }

  void _selectAction(GameAction action, [double? raiseAmount]) {
    _autoFoldTimer.cancel();
    widget.onActionSelected(action, raiseAmount);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: _secondsRemaining <= 5 ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto-fold in $_secondsRemaining seconds',
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondsRemaining <= 5 ? Colors.red : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            LinearProgressIndicator(
              value: _secondsRemaining / widget.autoFoldDuration.inSeconds,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _secondsRemaining <= 5 ? Colors.red : Colors.blue,
              ),
              minHeight: 4,
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
              children: [
                _buildMiniActionButton(
                  'FOLD',
                  Colors.red,
                  Icons.close,
                  () => _selectAction(GameAction.fold),
                ),

                if (widget.canCheck)
                  _buildMiniActionButton(
                    'CHECK',
                    Colors.blue,
                    Icons.check,
                    () => _selectAction(GameAction.check),
                  )
                else if (widget.canCall)
                  _buildMiniActionButton(
                    'CALL \$${(widget.currentBet - widget.playerCurrentBet).toStringAsFixed(0)}',
                    Colors.green,
                    Icons.call_received,
                    () => _selectAction(GameAction.call),
                  ),

                if (widget.canRaise)
                  _buildMiniActionButton(
                    'RAISE',
                    Colors.orange,
                    Icons.trending_up,
                    () {
                      showDialog(
                        context: context,
                        builder: (context) => ActionSelectionDialog(
                          onActionSelected: _selectAction,
                          currentBet: widget.currentBet,
                          playerCurrentBet: widget.playerCurrentBet,
                          playerChips: widget.playerChips,
                          canCheck: widget.canCheck,
                          canCall: widget.canCall,
                          canRaise: widget.canRaise,
                        ),
                      );
                    },
                  ),

                _buildMiniActionButton(
                  'ALL-IN',
                  Colors.purple,
                  Icons.all_inclusive,
                  () => _selectAction(GameAction.allIn),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Bet: \$${widget.currentBet.toStringAsFixed(0)} | Chips: \$${widget.playerChips.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: () {
        _resetTimer();
        onPressed();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      ),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
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
                          builder: (context) => TexasHoldemPage(),
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
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatDateTime(DateTime date) {
  return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
  Player? _humanPlayer;
  String _gameMessage = '';

  @override
  void initState() {
    super.initState();
    _gameMessage = 'Welcome to Texas Hold\'em!';
  }

  Future<void> _startGame() async {
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

    user.balance -= buyIn;
    await _dataManager.updateUser(user);

    final playerNames = [
      user.username,
      'AI Player 1',
      'AI Player 2',
      'AI Player 3',
      'AI Player 4',
      'AI Player 5',
      'AI Player 6',
      'AI Player 7',
      'AI Player 8',
    ];

    setState(() {
      _game = PokerGame(playerNames, buyIn, numPlayers: 9);
      _humanPlayer = _game!.players.firstWhere((p) => !p.isAI);
      _isGameActive = true;
      _gameMessage = 'Game started! Your turn.';
    });

    _processGame();
  }

  void _processGame() {
    if (_game == null || _game!.isGameOver) return;

    if (_game!.players[_game!.currentPlayerIndex].isAI) {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted || _game == null) return;

        _game!.makeAIAction();

        if (_game!._isBettingRoundComplete()) {
          _game!.nextRound();
          if (_game!.isGameOver) {
            _endGame();
          } else {
            setState(() {});
            _processGame();
          }
        } else if (_game!.isGameOver) {
          _endGame();
        } else {
          setState(() {});
          _processGame();
        }
      });
    } else {
      setState(() {
        _gameMessage = 'Your turn. ${_getCurrentBetInfo()}';
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
      if (_game!.isGameOver) {
        _endGame();
      } else {
        _processGame();
      }
    } else {
      _showMessage('Invalid action!');
    }
  }

  void _endGame() {
    if (_game == null) return;

    final user = _dataManager.currentUser;
    if (user != null && _humanPlayer != null) {
      user.balance += _humanPlayer!.chips;
      _dataManager.updateUser(user);

      user.gamesPlayed++;
      if (_game!.winners.contains(_humanPlayer)) {
        user.gamesWon++;
        user.points += 10;
      }
      _dataManager.updateUser(user);
    }

    if (_game!.winners.isNotEmpty) {
      String winnerNames = _game!.winners.map((w) => w.name).join(', ');
      _gameMessage =
          '🏆 Winners: $winnerNames! \nPot: \$${_game!.pot.toStringAsFixed(0)}';
    }

    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.blue),
    );
  }

  Widget _buildPlayerCard(int index) {
    if (_game == null || index >= _game!.players.length) {
      return const SizedBox();
    }

    final player = _game!.players[index];
    final isCurrentPlayer = index == _game!.currentPlayerIndex;
    final isHuman = !player.isAI;
    final isFolded = player.isFolded;
    final isAllIn = player.isAllIn;

    // Cards should be shown when:
    // 1. Player is human (you can see your own cards)
    // 2. Player is all-in
    // 3. It's showdown
    // 4. Player has folded
    // 5. All players are all-in
    final shouldShowCards =
        isHuman ||
        isAllIn ||
        _game!.currentRound == BettingRound.showdown ||
        isFolded ||
        _game!._areAllActivePlayersAllIn ||
        _game!.isGameOver;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    player.name.length > 8
                        ? '${player.name.substring(0, 8)}...'
                        : player.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isHuman ? Colors.green : Colors.black,
                      decoration: isFolded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isCurrentPlayer && !isFolded && !isAllIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
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
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
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
                if (isFolded)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FOLD',
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
              style: const TextStyle(fontSize: 11),
            ),
            if (player.currentBet > 0)
              Text(
                'Bet: \$${player.currentBet.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10),
              ),
            if (player.lastAction.isNotEmpty)
              Text(
                player.lastAction.length > 12
                    ? '${player.lastAction.substring(0, 12)}...'
                    : player.lastAction,
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (player.cards.isNotEmpty)
                  RealisticPlayingCard(
                    card: player.cards[0],
                    isHidden: !shouldShowCards,
                    width: 30,
                    height: 45,
                  ),
                const SizedBox(width: 2),
                if (player.cards.length > 1)
                  RealisticPlayingCard(
                    card: player.cards[1],
                    isHidden: !shouldShowCards,
                    width: 30,
                    height: 45,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Texas Hold\'em'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E40AF), Color(0xFF1E3A8A)],
          ),
        ),
        child: _isGameActive && _game != null
            ? _buildGameTable()
            : _buildSetupScreen(),
      ),
    );
  }

  Widget _buildSetupScreen() {
    final user = _dataManager.currentUser;

    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TEXAS HOLD\'EM',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
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
                    'START GAME',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTable() {
    return Column(
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
                    const Text('POT', style: TextStyle(fontSize: 12)),
                    Text(
                      '\$${_game!.pot.toStringAsFixed(0)}',
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
                    const Text('ROUND', style: TextStyle(fontSize: 12)),
                    Text(
                      _game!.currentRound.toString().split('.').last,
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

        // All-In Indicator
        if (_game!._areAllActivePlayersAllIn)
          Card(
            margin: const EdgeInsets.all(8),
            color: Colors.orange[100],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.all_inclusive,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ALL PLAYERS ALL-IN!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remaining cards dealt...',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
          ),

        // Community Cards
        Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'COMMUNITY CARDS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  alignment: WrapAlignment.center,
                  children: _game!.communityCards.map((card) {
                    return RealisticPlayingCard(
                      card: card,
                      width: 50,
                      height: 70,
                    );
                  }).toList(),
                ),
                if (_game!.communityCards.length < 5 && !_game!.isGameOver)
                  Text(
                    '${5 - _game!.communityCards.length} card(s) to come',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),

        // Players Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.8,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _game!.players.length,
            itemBuilder: (context, index) => _buildPlayerCard(index),
          ),
        ),

        // Action Panel
        if (_game != null &&
            _humanPlayer != null &&
            !_game!.isGameOver &&
            _game!.players[_game!.currentPlayerIndex] == _humanPlayer)
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    _gameMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () => _makeAction(GameAction.fold),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('FOLD'),
                      ),
                      if (_humanPlayer!.canCheck(_game!.currentBet))
                        ElevatedButton(
                          onPressed: () => _makeAction(GameAction.check),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text('CHECK'),
                        ),
                      if (!_humanPlayer!.canCheck(_game!.currentBet))
                        ElevatedButton(
                          onPressed: () => _makeAction(GameAction.call),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: Text(
                            'CALL \$${(_game!.currentBet - _humanPlayer!.currentBet).toStringAsFixed(0)}',
                          ),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => ActionSelectionDialog(
                              onActionSelected: (action, raiseAmount) {
                                if (action == GameAction.raise &&
                                    raiseAmount != null) {
                                  _makeAction(action, raiseAmount: raiseAmount);
                                } else {
                                  _makeAction(action);
                                }
                              },
                              currentBet: _game!.currentBet,
                              playerCurrentBet: _humanPlayer!.currentBet,
                              playerChips: _humanPlayer!.chips,
                              canCheck: _humanPlayer!.canCheck(
                                _game!.currentBet,
                              ),
                              canCall: _humanPlayer!.canCall(_game!.currentBet),
                              canRaise: _humanPlayer!.chips > 0,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('RAISE'),
                      ),
                      ElevatedButton(
                        onPressed: () => _makeAction(GameAction.allIn),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                        ),
                        child: Text(
                          'ALL-IN \$${_humanPlayer!.chips.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Game Over Screen
        if (_game != null && _game!.isGameOver)
          Card(
            margin: const EdgeInsets.all(8),
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _gameMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('QUIT'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isGameActive = false;
                            _game = null;
                            _gameMessage = 'Welcome to Texas Hold\'em!';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('PLAY AGAIN'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
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
  Timer? _aiActionTimer;

  @override
  void dispose() {
    _aiActionTimer?.cancel();
    super.dispose();
  }

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

    // Deduct bet from user balance
    user.balance -= bet;
    await _dataManager.updateUser(user);

    // Create 1 vs 1 game
    _game = PokerGame([user.username, 'AI Opponent'], bet, numPlayers: 2);
    _humanPlayer = _game!.players.firstWhere((p) => !p.isAI);

    setState(() {
      _isGameActive = true;
      _gameMessage = 'Game started! Your turn.';
    });
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
      // Check if game is over
      if (_game!.isGameOver) {
        _endGame();
      } else {
        // AI's turn
        setState(() {
          _gameMessage = 'AI Opponent\'s turn...';
        });

        // AI makes its move after delay
        _aiActionTimer?.cancel();
        _aiActionTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!mounted || _game == null || _game!.isGameOver) return;

          // Force AI to take action
          if (_game!.players[_game!.currentPlayerIndex].isAI) {
            _game!.makeAIAction();
          }

          if (!mounted) return;

          if (_game!.isGameOver) {
            _endGame();
          } else {
            // Check if it's still AI's turn (might have folded or all-in)
            if (_game!.players[_game!.currentPlayerIndex].isAI) {
              // If AI is still active, make another action
              _makeAction(GameAction.check); // Try check first
            } else {
              // Back to human player
              setState(() {
                _gameMessage = 'Your turn. ${_getCurrentBetInfo()}';
              });
            }
          }
        });
      }
    }
  }

  String _getCurrentBetInfo() {
    if (_game == null) return '';
    return 'Bet: \$${_game!.currentBet.toStringAsFixed(0)} | Pot: \$${_game!.pot.toStringAsFixed(0)}';
  }

  void _endGame() {
    if (_game == null) return;

    _aiActionTimer?.cancel();

    final user = _dataManager.currentUser;
    if (user != null && _humanPlayer != null) {
      // Update chips
      user.balance += _humanPlayer!.chips;

      // Update stats
      user.gamesPlayed++;
      if (_game!.winners.contains(_humanPlayer)) {
        user.gamesWon++;
        user.points += 10;
      }
      _dataManager.updateUser(user);
    }

    if (_game!.winners.isNotEmpty) {
      String winnerName = _game!.winners.first.name;
      if (winnerName == user?.username) {
        _gameMessage = '🏆 You win! \$${_game!.pot.toStringAsFixed(0)}';
      } else {
        _gameMessage = 'AI Opponent wins! \$${_game!.pot.toStringAsFixed(0)}';
      }
    }

    // SHOW ALL CARDS AT SHOWDOWN
    setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetGame() {
    _aiActionTimer?.cancel();
    setState(() {
      _game = null;
      _isGameActive = false;
      _humanPlayer = null;
      _gameMessage = '';
    });
  }

  Widget _buildGameTable() {
    if (_game == null) return Container();

    return SingleChildScrollView(
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
                      const Text('POT', style: TextStyle(fontSize: 12)),
                      Text(
                        '\$${_game!.pot.toStringAsFixed(0)}',
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
                      const Text('ROUND', style: TextStyle(fontSize: 12)),
                      Text(
                        _game!.currentRound.toString().split('.').last,
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

          // All-In Indicator
          if (_game!._areAllActivePlayersAllIn)
            Card(
              margin: const EdgeInsets.all(8),
              color: Colors.orange[100],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.all_inclusive,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'ALL PLAYERS ALL-IN!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remaining cards dealt...',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ],
                ),
              ),
            ),

          // Community Cards
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    'COMMUNITY CARDS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_game!.communityCards.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      alignment: WrapAlignment.center,
                      children: _game!.communityCards
                          .map(
                            (card) => RealisticPlayingCard(
                              card: card,
                              width: 50,
                              height: 70,
                            ),
                          )
                          .toList(),
                    )
                  else
                    Container(
                      width: 180,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Center(
                        child: Text(
                          'Community cards',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ),
                  if (_game!.communityCards.length < 5 && !_game!.isGameOver)
                    Text(
                      '${5 - _game!.communityCards.length} card(s) to come',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          // AI Opponent
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'AI OPPONENT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chips: \$${_game!.players[1].chips.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_game!.players[1].cards.isNotEmpty)
                        RealisticPlayingCard(
                          card: _game!.players[1].cards[0],
                          isHidden:
                              !(_game!.currentRound == BettingRound.showdown ||
                                  _game!.players[1].isAllIn ||
                                  _game!.players[1].isFolded ||
                                  _game!.isGameOver ||
                                  _game!._areAllActivePlayersAllIn),
                          width: 60,
                          height: 85,
                        ),
                      const SizedBox(width: 4),
                      if (_game!.players[1].cards.length > 1)
                        RealisticPlayingCard(
                          card: _game!.players[1].cards[1],
                          isHidden:
                              !(_game!.currentRound == BettingRound.showdown ||
                                  _game!.players[1].isAllIn ||
                                  _game!.players[1].isFolded ||
                                  _game!.isGameOver ||
                                  _game!._areAllActivePlayersAllIn),
                          width: 60,
                          height: 85,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Human Player
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    'YOU',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_humanPlayer != null)
                    Text(
                      'Chips: \$${_humanPlayer!.chips.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_humanPlayer?.cards.isNotEmpty ?? false)
                        RealisticPlayingCard(
                          card: _humanPlayer!.cards[0],
                          width: 60,
                          height: 85,
                        ),
                      const SizedBox(width: 4),
                      if ((_humanPlayer?.cards.length ?? 0) > 1)
                        RealisticPlayingCard(
                          card: _humanPlayer!.cards[1],
                          width: 60,
                          height: 85,
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
                padding: const EdgeInsets.all(8),
                child: Text(
                  _gameMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Action Buttons (visible when it's player's turn)
          if (!_game!.isGameOver &&
              !_game!.players[_game!.currentPlayerIndex].isAI &&
              !_game!.players[_game!.currentPlayerIndex].isFolded &&
              !_game!.players[_game!.currentPlayerIndex].isAllIn)
            Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Fold Button
                        MaterialButton(
                          onPressed: () => _makeAction(GameAction.fold),
                          color: Colors.red,
                          textColor: Colors.white,
                          child: const Text('FOLD'),
                        ),

                        // Check/Call Button
                        if (_humanPlayer!.canCheck(_game!.currentBet))
                          MaterialButton(
                            onPressed: () => _makeAction(GameAction.check),
                            color: Colors.blue,
                            textColor: Colors.white,
                            child: const Text('CHECK'),
                          )
                        else if (_humanPlayer!.canCall(_game!.currentBet))
                          MaterialButton(
                            onPressed: () => _makeAction(GameAction.call),
                            color: Colors.green,
                            textColor: Colors.white,
                            child: Text(
                              'CALL \$${(_game!.currentBet - _humanPlayer!.currentBet).toStringAsFixed(0)}',
                            ),
                          ),

                        // Raise Button
                        if (_humanPlayer!.chips > 0)
                          MaterialButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => ActionSelectionDialog(
                                  onActionSelected: (action, raiseAmount) {
                                    if (action == GameAction.raise &&
                                        raiseAmount != null) {
                                      _makeAction(
                                        action,
                                        raiseAmount: raiseAmount,
                                      );
                                    } else {
                                      _makeAction(action);
                                    }
                                  },
                                  currentBet: _game!.currentBet,
                                  playerCurrentBet: _humanPlayer!.currentBet,
                                  playerChips: _humanPlayer!.chips,
                                  canCheck: _humanPlayer!.canCheck(
                                    _game!.currentBet,
                                  ),
                                  canCall: _humanPlayer!.canCall(
                                    _game!.currentBet,
                                  ),
                                  canRaise: _humanPlayer!.chips > 0,
                                ),
                              );
                            },
                            color: Colors.orange,
                            textColor: Colors.white,
                            child: const Text('RAISE'),
                          ),

                        // All-In Button
                        if (_humanPlayer!.chips > 0)
                          MaterialButton(
                            onPressed: () => _makeAction(GameAction.allIn),
                            color: Colors.purple,
                            textColor: Colors.white,
                            child: const Text('ALL-IN'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Game Over Screen
          if (_game!.isGameOver)
            Card(
              margin: const EdgeInsets.all(16),
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _gameMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: MaterialButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            color: Colors.red,
                            textColor: Colors.white,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('QUIT'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: MaterialButton(
                            onPressed: _resetGame,
                            color: Colors.green,
                            textColor: Colors.white,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('PLAY AGAIN'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _dataManager.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('1 vs 1 Texas Hold\'em'),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
              // Game Setup Screen
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
              Expanded(child: _buildGameTable()),
            ],
          ],
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

  @override
  Widget build(BuildContext context) {
    final user = _dataManager.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Tournament'),
        backgroundColor: Colors.amber,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Simulating tournament...',
                            style: TextStyle(fontSize: 16, color: Colors.white),
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

    user.balance -= entryFee;
    await _dataManager.updateUser(user);

    setState(() {
      _isPlaying = true;
      _tournamentResult = null;
    });

    await Future.delayed(const Duration(seconds: 3));

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

    if (!mounted) return;

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
