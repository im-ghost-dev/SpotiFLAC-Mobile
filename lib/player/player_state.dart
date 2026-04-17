// lib/player/player_state.dart

import 'package:audio_service/audio_service.dart';

class PlayerTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final String? artworkPath;
  final Duration duration;

  const PlayerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    this.artworkPath,
    this.duration = Duration.zero,
  });

  MediaItem toMediaItem() => MediaItem(
        id: filePath,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        artUri: artworkPath != null ? Uri.file(artworkPath!) : null,
      );

  factory PlayerTrack.fromMediaItem(MediaItem item) => PlayerTrack(
        id: item.id,
        title: item.title,
        artist: item.artist ?? 'Unknown Artist',
        album: item.album ?? 'Unknown Album',
        filePath: item.id,
        artworkPath: item.artUri?.toFilePath(),
        duration: item.duration ?? Duration.zero,
      );
}

class PlayerAppState {
  final PlayerTrack? currentTrack;
  final List<PlayerTrack> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double volume;
  final LoopMode loopMode;
  final bool shuffleEnabled;

  const PlayerAppState({
    this.currentTrack,
    this.queue = const [],
    this.currentIndex = 0,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.loopMode = LoopMode.off,
    this.shuffleEnabled = false,
  });

  bool get hasTrack => currentTrack != null;

  double get progress {
    if (duration.inMilliseconds == 0) return 0.0;
    return position.inMilliseconds / duration.inMilliseconds;
  }

  PlayerAppState copyWith({
    PlayerTrack? currentTrack,
    List<PlayerTrack>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? volume,
    LoopMode? loopMode,
    bool? shuffleEnabled,
  }) =>
      PlayerAppState(
        currentTrack: currentTrack ?? this.currentTrack,
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        isLoading: isLoading ?? this.isLoading,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        volume: volume ?? this.volume,
        loopMode: loopMode ?? this.loopMode,
        shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      );
}

