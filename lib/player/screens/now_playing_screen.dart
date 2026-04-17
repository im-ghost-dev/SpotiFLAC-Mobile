// lib/player/screens/now_playing_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../player_controller.dart';
import '../player_state.dart';

class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    if (!state.hasTrack) {
      return const Scaffold(
        body: Center(child: Text('Nothing is playing')),
      );
    }

    final track = state.currentTrack!;
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _TopBar(),
            const SizedBox(height: 24),

            // Album art
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _AlbumArtLarge(
                artworkPath: track.artworkPath,
                isPlaying: state.isPlaying,
                size: size.width - 64,
              ),
            ),
            const SizedBox(height: 32),

            // Track info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _TrackInfo(track: track),
            ),
            const SizedBox(height: 24),

            // Seek bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SeekBar(
                position: state.position,
                duration: state.duration,
                onSeek: controller.seekTo,
              ),
            ),
            const SizedBox(height: 16),

            // Main controls
            _MainControls(
              isPlaying: state.isPlaying,
              isLoading: state.isLoading,
              loopMode: state.loopMode,
              shuffleEnabled: state.shuffleEnabled,
              onPlayPause: controller.togglePlayPause,
              onNext: controller.skipToNext,
              onPrevious: controller.skipToPrevious,
              onToggleShuffle: controller.toggleShuffle,
              onCycleLoop: controller.cycleLoopMode,
            ),
            const SizedBox(height: 16),

            // Volume slider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _VolumeRow(
                volume: state.volume,
                onChanged: controller.setVolume,
              ),
            ),
            const SizedBox(height: 16),

            // Queue button
            if (state.queue.length > 1)
              TextButton.icon(
                onPressed: () => _showQueue(context, state, controller),
                icon: const Icon(Icons.queue_music_rounded),
                label: Text('Queue (${state.queue.length} tracks)'),
              ),
          ],
        ),
      ),
    );
  }

  void _showQueue(BuildContext context, PlayerAppState state, PlayerController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _QueueSheet(state: state, controller: controller),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Now Playing',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ── Album art ───────────────────────────────────────────

class _AlbumArtLarge extends StatelessWidget {
  final String? artworkPath;
  final bool isPlaying;
  final double size;

  const _AlbumArtLarge({this.artworkPath, required this.isPlaying, required this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isPlaying ? size : size * 0.85,
      height: isPlaying ? size : size * 0.85,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: isPlaying ? 32 : 12,
            spreadRadius: isPlaying ? 4 : 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: artworkPath != null
            ? Image.asset(artworkPath!, fit: BoxFit.cover)
            : Container(
                color: colorScheme.secondaryContainer,
                child: Icon(
                  Icons.music_note_rounded,
                  size: size * 0.4,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
      ),
    );
  }
}

// ── Track info ──────────────────────────────────────────

class _TrackInfo extends StatelessWidget {
  final PlayerTrack track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (track.album.isNotEmpty)
                Text(
                  track.album,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Seek bar ────────────────────────────────────────────

class _SeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.duration.inMilliseconds.toDouble();
    final current = _dragValue ?? widget.position.inMilliseconds.toDouble();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest,
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withOpacity(0.2),
          ),
          child: Slider(
            min: 0,
            max: total > 0 ? total : 1,
            value: current.clamp(0, total > 0 ? total : 1),
            onChanged: (value) => setState(() => _dragValue = value),
            onChangeEnd: (value) {
              widget.onSeek(Duration(milliseconds: value.round()));
              setState(() => _dragValue = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _format(Duration(milliseconds: current.round())),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                _format(widget.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Main controls ───────────────────────────────────────

class _MainControls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final LoopMode loopMode;
  final bool shuffleEnabled;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleLoop;

  const _MainControls({
    required this.isPlaying,
    required this.isLoading,
    required this.loopMode,
    required this.shuffleEnabled,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleShuffle,
    required this.onCycleLoop,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: shuffleEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            onPressed: onToggleShuffle,
          ),
          // Previous
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 36),
            onPressed: onPrevious,
          ),
          // Play/Pause
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 36,
                      color: colorScheme.onPrimaryContainer,
                    ),
              onPressed: onPlayPause,
            ),
          ),
          // Next
          IconButton(
            icon: const Icon(Icons.skip_next_rounded, size: 36),
            onPressed: onNext,
          ),
          // Loop mode
          IconButton(
            icon: Icon(
              loopMode == LoopMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: loopMode != LoopMode.off
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            onPressed: onCycleLoop,
          ),
        ],
      ),
    );
  }
}

// ── Volume row ──────────────────────────────────────────

class _VolumeRow extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;

  const _VolumeRow({required this.volume, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.volume_down_rounded, color: colorScheme.onSurfaceVariant, size: 20),
        Expanded(
          child: Slider(
            value: volume,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.surfaceContainerHighest,
          ),
        ),
        Icon(Icons.volume_up_rounded, color: colorScheme.onSurfaceVariant, size: 20),
      ],
    );
  }
}

// ── Queue bottom sheet ──────────────────────────────────

class _QueueSheet extends StatelessWidget {
  final PlayerAppState state;
  final PlayerController controller;

  const _QueueSheet({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Text(
                  'Queue',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${state.queue.length} tracks',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: state.queue.length,
              itemBuilder: (context, index) {
                final track = state.queue[index];
                final isCurrent = index == state.currentIndex;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCurrent ? Icons.equalizer_rounded : Icons.music_note_rounded,
                      color: isCurrent
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
                      color: isCurrent ? colorScheme.primary : null,
                    ),
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    controller.skipToIndex(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

