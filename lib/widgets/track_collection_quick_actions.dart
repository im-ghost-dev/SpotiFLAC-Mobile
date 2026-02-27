import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/models/track.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';
import 'package:spotiflac_android/providers/library_collections_provider.dart';
import 'package:spotiflac_android/providers/local_library_provider.dart';
import 'package:spotiflac_android/providers/playback_provider.dart';
import 'package:spotiflac_android/providers/settings_provider.dart';
import 'package:spotiflac_android/services/cover_cache_manager.dart';
import 'package:spotiflac_android/utils/file_access.dart';
import 'package:spotiflac_android/widgets/download_service_picker.dart';
import 'package:spotiflac_android/widgets/playlist_picker_sheet.dart';
import 'package:spotiflac_android/utils/clickable_metadata.dart';

class TrackCollectionQuickActions extends ConsumerWidget {
  final Track track;

  const TrackCollectionQuickActions({super.key, required this.track});

  static void showTrackOptionsSheet(
    BuildContext context,
    WidgetRef ref,
    Track track,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _TrackOptionsSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onPressed: () => showTrackOptionsSheet(context, ref, track),
      padding: const EdgeInsets.only(left: 12),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}

class _TrackOptionsSheet extends ConsumerWidget {
  final Track track;

  const _TrackOptionsSheet({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final container = ProviderScope.containerOf(rootContext, listen: false);

    final isLoved = ref.watch(
      libraryCollectionsProvider.select((state) => state.isLoved(track)),
    );
    final isInWishlist = ref.watch(
      libraryCollectionsProvider.select((state) => state.isInWishlist(track)),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with drag handle + track info (matches _TrackInfoHeader)
              Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child:
                              track.coverUrl != null &&
                                  track.coverUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: track.coverUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 112,
                                  cacheManager: CoverCacheManager.instance,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 56,
                                        height: 56,
                                        color:
                                            colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.music_note,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.music_note,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              ClickableArtistName(
                                artistName: track.artistName,
                                artistId: track.artistId,
                                coverUrl: track.coverUrl,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),

              // Action items (matches _QualityOption style)
              _OptionTile(
                icon: Icons.download_rounded,
                title: 'Download & Play',
                onTap: () async {
                  Navigator.pop(context);
                  final playedLocal = await _playLocalIfAvailable(
                    container,
                    rootContext,
                  );
                  if (playedLocal) {
                    return;
                  }
                  if (!rootContext.mounted) {
                    return;
                  }

                  if (settings.askQualityBeforeDownload) {
                    DownloadServicePicker.show(
                      rootContext,
                      trackName: track.name,
                      artistName: track.artistName,
                      coverUrl: track.coverUrl,
                      onSelect: (quality, service) {
                        _enqueueDownloadAndAutoPlay(
                          container: container,
                          context: rootContext,
                          service: service,
                          quality: quality,
                        );
                      },
                    );
                  } else {
                    _enqueueDownloadAndAutoPlay(
                      container: container,
                      context: rootContext,
                      service: settings.defaultService,
                    );
                  }
                },
              ),
              _OptionTile(
                icon: isLoved ? Icons.favorite : Icons.favorite_border,
                iconColor: isLoved ? colorScheme.error : null,
                title: isLoved
                    ? context.l10n.trackOptionRemoveFromLoved
                    : context.l10n.trackOptionAddToLoved,
                onTap: () async {
                  Navigator.pop(context);
                  final added = await ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleLoved(track);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added
                            ? context.l10n.collectionAddedToLoved(track.name)
                            : context.l10n.collectionRemovedFromLoved(
                                track.name,
                              ),
                      ),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: isInWishlist
                    ? Icons.playlist_add_check_circle
                    : Icons.add_circle_outline,
                iconColor: isInWishlist ? colorScheme.primary : null,
                title: isInWishlist
                    ? context.l10n.trackOptionRemoveFromWishlist
                    : context.l10n.trackOptionAddToWishlist,
                onTap: () async {
                  Navigator.pop(context);
                  final added = await ref
                      .read(libraryCollectionsProvider.notifier)
                      .toggleWishlist(track);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        added
                            ? context.l10n.collectionAddedToWishlist(track.name)
                            : context.l10n.collectionRemovedFromWishlist(
                                track.name,
                              ),
                      ),
                    ),
                  );
                },
              ),
              _OptionTile(
                icon: Icons.playlist_add,
                title: context.l10n.collectionAddToPlaylist,
                onTap: () {
                  Navigator.pop(context);
                  showAddTrackToPlaylistSheet(context, ref, track);
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _playLocalIfAvailable(
    ProviderContainer container,
    BuildContext context,
  ) async {
    final localState = container.read(localLibraryProvider);
    final historyState = container.read(downloadHistoryProvider);
    final historyNotifier = container.read(downloadHistoryProvider.notifier);

    try {
      DownloadHistoryItem? historyItem = historyNotifier.getBySpotifyId(
        track.id,
      );
      final isrc = track.isrc?.trim();
      historyItem ??= (isrc != null && isrc.isNotEmpty)
          ? historyNotifier.getByIsrc(isrc)
          : null;
      historyItem ??= historyState.findByTrackAndArtist(
        track.name,
        track.artistName,
      );

      if (historyItem != null) {
        final exists = await fileExists(historyItem.filePath);
        if (exists) {
          await container
              .read(playbackProvider.notifier)
              .playLocalPath(
                path: historyItem.filePath,
                title: track.name,
                artist: track.artistName,
                album: track.albumName,
                coverUrl: track.coverUrl ?? '',
              );
          return true;
        }
        historyNotifier.removeFromHistory(historyItem.id);
      }

      var localItem = (isrc != null && isrc.isNotEmpty)
          ? localState.getByIsrc(isrc)
          : null;
      localItem ??= localState.findByTrackAndArtist(
        track.name,
        track.artistName,
      );

      if (localItem != null && await fileExists(localItem.filePath)) {
        await container
            .read(playbackProvider.notifier)
            .playLocalPath(
              path: localItem.filePath,
              title: localItem.trackName,
              artist: localItem.artistName,
              album: localItem.albumName,
              coverUrl: localItem.coverPath ?? track.coverUrl ?? '',
            );
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.snackbarCannotOpenFile('$e'))),
        );
      }
      return true;
    }

    return false;
  }

  void _enqueueDownloadAndAutoPlay({
    required ProviderContainer container,
    required BuildContext context,
    required String service,
    String? quality,
  }) {
    container
        .read(downloadQueueProvider.notifier)
        .addToQueue(track, service, qualityOverride: quality);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.snackbarAddedToQueue(track.name))),
      );
    }
    unawaited(_waitForDownloadedFileAndPlay(container, context));
  }

  Future<void> _waitForDownloadedFileAndPlay(
    ProviderContainer container,
    BuildContext context,
  ) async {
    const maxAttempts = 180; // up to ~3 minutes
    for (var i = 0; i < maxAttempts; i++) {
      final item = _findHistoryMatch(container);
      if (item != null && await fileExists(item.filePath)) {
        try {
          await container
              .read(playbackProvider.notifier)
              .playLocalPath(
                path: item.filePath,
                title: track.name,
                artist: track.artistName,
                album: track.albumName,
                coverUrl: track.coverUrl ?? '',
              );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.snackbarCannotOpenFile('$e')),
              ),
            );
          }
        }
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  DownloadHistoryItem? _findHistoryMatch(ProviderContainer container) {
    final historyState = container.read(downloadHistoryProvider);
    final historyNotifier = container.read(downloadHistoryProvider.notifier);
    final isrc = track.isrc?.trim();

    return historyNotifier.getBySpotifyId(track.id) ??
        ((isrc != null && isrc.isNotEmpty)
            ? historyNotifier.getByIsrc(isrc)
            : null) ??
        historyState.findByTrackAndArtist(track.name, track.artistName);
  }
}

/// Styled like _QualityOption in download_service_picker.dart
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? colorScheme.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
