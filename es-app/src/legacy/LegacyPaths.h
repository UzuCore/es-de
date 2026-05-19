//  SPDX-License-Identifier: MIT
//
//  ES-DE Frontend
//  LegacyPaths.h
//
//  Helpers for "LegacyGamelistFileLocation" mode (ROM-folder media layout).
//
//  Centralizing this logic in one module keeps the surface area in upstream
//  source files minimal, so merging future ES-DE upstream changes stays easy.
//
//  When Legacy mode is OFF, every helper returns std::nullopt / empty / false
//  so the caller falls through to the default ES-DE behavior unchanged.
//

#ifndef ES_APP_LEGACY_LEGACY_PATHS_H
#define ES_APP_LEGACY_LEGACY_PATHS_H

#include <optional>
#include <string>
#include <vector>

class FileData;
class SystemData;
struct ScraperSearchParams;

namespace Legacy
{
    // True when "LegacyGamelistFileLocation" setting is enabled.
    bool isEnabled();

    // gamelist.xml path resolution.
    // Returns the path when Legacy mode handled it (including the empty string
    // case meaning "file not found for read"); returns std::nullopt to let the
    // default ES-DE logic run.
    std::optional<std::string> resolveGamelistPath(const std::string& romFolderPath,
                                                   const std::string& filePath,
                                                   bool forWrite);

    // Scraper save-as path: <ROM>/<system>/media/<es-type>/<sub>/<name><ext>
    // Returns std::nullopt outside Legacy mode.
    std::optional<std::string> resolveScraperSavePath(const ScraperSearchParams& params,
                                                      const std::string& filetypeSubdirectory,
                                                      const std::string& subFolders,
                                                      const std::string& name,
                                                      const std::string& extension);

    // Miximage output directory. Returns std::nullopt outside Legacy mode.
    // The returned path already ends with '/'.
    std::optional<std::string> resolveMiximagePath(const std::string& romStartPath,
                                                   const std::string& subFolders);

    // Screensaver image dirs for a given system root folder (one call replaces
    // four assignments). Outputs are written via out params; returns true when
    // Legacy values were written, false otherwise.
    bool resolveScreensaverImageDirs(const std::string& systemRomPath,
                                     std::string& outMiximages,
                                     std::string& outScreenshots,
                                     std::string& outTitlescreens,
                                     std::string& outCovers);

    // Screensaver video dir. Returns std::nullopt outside Legacy mode.
    std::optional<std::string> resolveScreensaverVideoDir(const std::string& systemRomPath);

    // Media-removal base dir used by GamelistBase::removeMedia.
    // Returns std::nullopt outside Legacy mode.
    std::optional<std::string> resolveRemoveMediaDir(const std::string& systemRomPath);

    // Orphaned-data-cleanup overrides. When Legacy mode is on, fills the out
    // params with the ROM-folder media dir and the ES-style type list and
    // returns true; otherwise returns false and leaves params untouched.
    bool resolveOrphanedCleanupDirs(const std::string& systemRomPath,
                                    std::string& outSystemMediaDir,
                                    std::vector<std::string>& outMediaTypesToScan);

    // Orphaned-data-cleanup CLEANUP destination base.
    // Returns std::nullopt outside Legacy mode.
    std::optional<std::string> resolveCleanupBaseDir(const std::string& systemRomPath);

    // Extra scan pass performed at the end of GamelistBase::removeMedia in
    // Legacy mode (no-op otherwise). Removes any leftover file whose stem
    // matches the game stem under <systemMediaDir>/*/.
    void scanAndRemoveLeftoverMedia(const std::string& systemMediaDir,
                                    const std::string& gameFilePath);

    // Scraper helpers ------------------------------------------------------

    // Map ES-DE media subdirectory (e.g. "screenshots") to the ES folder name
    // used on disk in Legacy mode (e.g. "images"). Unknown names pass through.
    std::string mapMediaSubdirToESStyle(const std::string& esdeSubdir);

    // Map ES-DE media subdirectory to the gamelist.xml metadata key used in
    // Legacy mode (e.g. "screenshots" -> "image"). Returns "" if the type has
    // no metadata key.
    std::string mapMediaSubdirToMDKey(const std::string& esdeSubdir);

    // Write a relative-path entry into the game's metadata after a scrape
    // download finishes. No-op when not in Legacy mode, mdKey is empty, or
    // game is null. Path is normalized and made relative to startPath.
    void updateMetadataRelativePath(FileData* game,
                                    const std::string& mdKey,
                                    const std::string& startPath,
                                    const std::string& filePath);
} // namespace Legacy

#endif // ES_APP_LEGACY_LEGACY_PATHS_H
