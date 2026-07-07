import 'package:flutter/material.dart';
import '../models/card_model.dart';

class PlayingCard extends StatelessWidget {
  final CardModel card;
  final bool isSelected;
  final bool isPlayable;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const PlayingCard({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isPlayable = false,
    this.onTap,
    this.width = 60,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    final color = card.isRed ? const Color(0xFFE53935) : Colors.white;
    return GestureDetector(
      onTap: isPlayable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: height,
        margin: EdgeInsets.only(bottom: isSelected ? 16 : 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CAF50)
                : isPlayable
                    ? Colors.yellow.withValues(alpha: 0.7)
                    : Colors.grey.shade300,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
                  : Colors.black26,
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 6,
              child: Column(
                children: [
                  Text(card.rank,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  Text(card.suitSymbol,
                      style: TextStyle(color: color, fontSize: 11)),
                ],
              ),
            ),
            Center(
              child: Text(
                card.suitSymbol,
                style: TextStyle(color: color, fontSize: 28),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 6,
              child: RotatedBox(
                quarterTurns: 2,
                child: Column(
                  children: [
                    Text(card.rank,
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Text(card.suitSymbol,
                        style: TextStyle(color: color, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CardBack extends StatelessWidget {
  final double width;
  final double height;

  const CardBack({super.key, this.width = 60, this.height = 90});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.style, color: Colors.white24, size: 24),
        ),
      ),
    );
  }
}
