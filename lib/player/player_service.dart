// lib/player/player_service.dart

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

Future<AudioPlayerHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.spotiflac.player',
      androidNotificationChannelName: 'SpotiFLAC Player',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: null,
    ),
  );
}

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  AudioPlayerHandler() {
    _init();
  }

  Future<void> _init() async {
    await _player.setAudioSource(_playlist);

    // Broadcast playback state changes
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Broadcast current media item
    _player.currentIndexStream.listen((index) {
      if (index != null && queue.value.isNotEmpty) {
        mediaItem.add(queue.value[index]);
      }
    });

    // Broadcast queue updates
    _player.sequenceStateStream.listen((state) {
      if (state != null) {
        final newQueue = state.effectiveSequence
            .map((src) => src.tag as MediaItem)
            .toList();
        queue.add(newQueue);
        if (state.currentIndex < newQueue.length) {
          mediaItem.add(newQueue[state.currentIndex]);
        }
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  // ── Public API ──────────────────────────────────────────

  AudioPlayer get audioPlayer => _player;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async {
    await _player.seek(Duration.zero, index: index);
    play();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await _player.setShuffleModeEnabled(
      shuffleMode == AudioServiceShuffleMode.all,
    );
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode({
      AudioServiceRepeatMode.none: LoopMode.off,
      AudioServiceRepeatMode.one: LoopMode.one,
      AudioServiceRepeatMode.all: LoopMode.all,
    }[repeatMode]!);
  }

  Future<void> playTrack(MediaItem item) async {
    await _playlist.clear();
    await _playlist.add(AudioSource.file(item.id, tag: item));
    queue.add([item]);
    mediaItem.add(item);
    await play();
  }

  Future<void> playQueue(List<MediaItem> items, {int startIndex = 0}) async {
    await _playlist.clear();
    await _playlist.addAll(
      items.map((item) => AudioSource.file(item.id, tag: item)).toList(),
    );
    queue.add(items);
    await _player.seek(Duration.zero, index: startIndex);
    await play();
  }

  Future<void> addToQueue(MediaItem item) async {
    await _playlist.add(AudioSource.file(item.id, tag: item));
    queue.add([...queue.value, item]);
  }

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
