// lib/player/player_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'player_service.dart';
import 'player_state.dart';

// Global handler instance provider
final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main.dart');
});

// Main player state provider
final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerAppState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return PlayerController(handler);
});

// Position stream provider (separate for performance)
final playerPositionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.positionStream;
});

class PlayerController extends StateNotifier<PlayerAppState> {
  final AudioPlayerHandler _handler;

  PlayerController(this._handler) : super(const PlayerAppState()) {
    _listenToStreams();
  }

  void _listenToStreams() {
    _handler.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    _handler.durationStream.listen((duration) {
      if (duration != null) state = state.copyWith(duration: duration);
    });

    _handler.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    _handler.processingStateStream.listen((ps) {
      state = state.copyWith(isLoading: ps == ProcessingState.loading || ps == ProcessingState.buffering);
    });

    _handler.mediaItem.listen((item) {
      if (item != null) {
        state = state.copyWith(currentTrack: PlayerTrack.fromMediaItem(item));
      }
    });

    _handler.queue.listen((queue) {
      state = state.copyWith(
        queue: queue.map((item) => PlayerTrack.fromMediaItem(item)).toList(),
      );
    });
  }

  // ── Controls ──────────────────────────────────────────

  Future<void> playTrack(PlayerTrack track) async {
    state = state.copyWith(isLoading: true);
    await _handler.playTrack(track.toMediaItem());
  }

  Future<void> playQueue(List<PlayerTrack> tracks, {int startIndex = 0}) async {
    state = state.copyWith(isLoading: true);
    await _handler.playQueue(
      tracks.map((t) => t.toMediaItem()).toList(),
      startIndex: startIndex,
    );
  }

  Future<void> addToQueue(PlayerTrack track) async {
    await _handler.addToQueue(track.toMediaItem());
  }

  Future<void> togglePlayPause() async {
    state.isPlaying ? await _handler.pause() : await _handler.play();
  }

  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();

  Future<void> seekTo(Duration position) => _handler.seek(position);

  Future<void> seekToFraction(double fraction) {
    final ms = (fraction * state.duration.inMilliseconds).round();
    return seekTo(Duration(milliseconds: ms));
  }

  Future<void> skipToNext() => _handler.skipToNext();
  Future<void> skipToPrevious() => _handler.skipToPrevious();

  Future<void> skipToIndex(int index) => _handler.skipToQueueItem(index);

  Future<void> toggleShuffle() async {
    final enabled = !state.shuffleEnabled;
    state = state.copyWith(shuffleEnabled: enabled);
    await _handler.setShuffleMode(
      enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  Future<void> cycleLoopMode() async {
    final next = {
      LoopMode.off: LoopMode.all,
      LoopMode.all: LoopMode.one,
      LoopMode.one: LoopMode.off,
    }[state.loopMode]!;
    state = state.copyWith(loopMode: next);
    await _handler.setRepeatMode({
      LoopMode.off: AudioServiceRepeatMode.none,
      LoopMode.all: AudioServiceRepeatMode.all,
      LoopMode.one: AudioServiceRepeatMode.one,
    }[next]!);
  }

  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume);
    await _handler.setVolume(volume);
  }

  Future<void> stop() => _handler.stop();
}

