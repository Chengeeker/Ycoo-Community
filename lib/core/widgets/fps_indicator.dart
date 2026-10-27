import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FpsIndicator extends StatefulWidget {
  const FpsIndicator({super.key});
  @override
  State<FpsIndicator> createState() => _FpsIndicatorState();
}

class _FpsIndicatorState extends State<FpsIndicator>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  int frames = 0, fps = 0;
  Duration last = Duration.zero;
  @override
  void initState() {
    super.initState();
    ticker = createTicker((elapsed) {
      frames++;
      final interval = elapsed - last;
      if (interval.inMilliseconds >= 1000) {
        setState(
          () => fps = (frames * 1000000 / interval.inMicroseconds).round(),
        );
        frames = 0;
        last = elapsed;
      }
    })..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: .85),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text('$fps FPS', style: Theme.of(context).textTheme.labelSmall),
      ),
    ),
  );
}
