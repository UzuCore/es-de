//  SPDX-License-Identifier: MIT
//
//  ES-DE Frontend
//  LegacyPaths.cpp
//
//  See LegacyPaths.h for the rationale: keep all "LegacyGamelistFileLocation"
//  behavior in this single translation unit so upstream merges stay clean.
//

#include "legacy/LegacyPaths.h"

#include "FileData.h"
#include "Log.h"
#include "Settings.h"
#include "SystemData.h"
#include "scrapers/Scraper.h"
#include "utils/FileSystemUtil.h"
#include "utils/StringUtil.h"

namespace
{
    // Trailing-slash guarantee for path concatenation.
    inline void ensureTrailingSlash(std::string& p)
    {
        if (p.empty())
            return;
        const char back {p.back()};
        if (back != '/' && back != '\\')
            p.append("/");
    }
} // namespace

namespace Legacy
{
    bool isEnabled()
    {
        return Settings::getInstance()->getBool("LegacyGamelistFileLocation");
    }

    // ---------------------------------------------------------------- gamelist

    std::optional<std::string> resolveGamelistPath(const std::string& /*romFolderPath*/,
                                                   const std::string& filePath,
                                                   bool forWrite)
    {
        if (!isEnabled())
            return std::nullopt;

        // Legacy: always read/write inside the ROM folder.
        if (forWrite)
            Utils::FileSystem::createDirectory(Utils::FileSystem::getParent(filePath));
        if (forWrite || Utils::FileSystem::exists(filePath))
            return filePath;
        return std::string {};
    }

    // ---------------------------------------------------------------- scraper save path

    std::optional<std::string> resolveScraperSavePath(const ScraperSearchParams& params,
                                                      const std::string& filetypeSubdirectory,
                                                      const std::string& subFolders,
                                                      const std::string& name,
                                                      const std::string& extension)
    {
        if (!isEnabled())
            return std::nullopt;

        std::string path {params.system->getSystemEnvData()->mStartPath};
        ensureTrailingSlash(path);

        path.append("media/")
            .append(mapMediaSubdirToESStyle(filetypeSubdirectory))
            .append(subFolders)
            .append("/");

        if (!Utils::FileSystem::exists(path))
            Utils::FileSystem::createDirectory(path);

        path.append(name).append(extension);
        return path;
    }

    // ---------------------------------------------------------------- miximage

    std::optional<std::string> resolveMiximagePath(const std::string& romStartPath,
                                                   const std::string& subFolders)
    {
        if (!isEnabled())
            return std::nullopt;

        std::string path {romStartPath};
        ensureTrailingSlash(path);
        path += "media/miximages" + subFolders + "/";
        return path;
    }

    // ---------------------------------------------------------------- screensaver

    bool resolveScreensaverImageDirs(const std::string& systemRomPath,
                                     std::string& outMiximages,
                                     std::string& outScreenshots,
                                     std::string& outTitlescreens,
                                     std::string& outCovers)
    {
        if (!isEnabled())
            return false;

        const std::string romPath {Utils::String::replace(systemRomPath, "\\", "/")};
        outMiximages = romPath + "/media/miximages";
        outScreenshots = romPath + "/media/images";
        outTitlescreens = romPath + "/media/titlescreens";
        outCovers = romPath + "/media/thumbnails";
        return true;
    }

    std::optional<std::string> resolveScreensaverVideoDir(const std::string& systemRomPath)
    {
        if (!isEnabled())
            return std::nullopt;
        const std::string romPath {Utils::String::replace(systemRomPath, "\\", "/")};
        return romPath + "/media/videos";
    }

    // ---------------------------------------------------------------- remove-media base

    std::optional<std::string> resolveRemoveMediaDir(const std::string& systemRomPath)
    {
        if (!isEnabled())
            return std::nullopt;
        return systemRomPath + "/media";
    }

    // ---------------------------------------------------------------- orphan cleanup

    bool resolveOrphanedCleanupDirs(const std::string& systemRomPath,
                                    std::string& outSystemMediaDir,
                                    std::vector<std::string>& outMediaTypesToScan)
    {
        if (!isEnabled())
            return false;

        outSystemMediaDir = systemRomPath + "/media";
        outMediaTypesToScan = {"images", "thumbnails", "marquees",  "videos",
                               "fanart", "manuals",    "miximages", "titlescreens"};
        return true;
    }

    std::optional<std::string> resolveCleanupBaseDir(const std::string& systemRomPath)
    {
        if (!isEnabled())
            return std::nullopt;
        return systemRomPath + "/";
    }

    // ---------------------------------------------------------------- leftover scan

    void scanAndRemoveLeftoverMedia(const std::string& systemMediaDir,
                                    const std::string& gameFilePath)
    {
        if (!isEnabled())
            return;
        if (!Utils::FileSystem::isDirectory(systemMediaDir))
            return;

        const std::string gameStem {Utils::FileSystem::getStem(gameFilePath)};
        const Utils::FileSystem::StringList& subdirs {
            Utils::FileSystem::getDirContent(systemMediaDir, false)};

        for (auto& subdir : subdirs) {
            if (!Utils::FileSystem::isDirectory(subdir))
                continue;
            const Utils::FileSystem::StringList& dirContent {
                Utils::FileSystem::getDirContent(subdir, true)};
            for (auto& mediaFile : dirContent) {
                if (Utils::FileSystem::isDirectory(mediaFile))
                    continue;
                if (Utils::FileSystem::getStem(mediaFile) != gameStem)
                    continue;
                LOG(LogInfo) << "Removing orphaned media file \"" << mediaFile << "\"";
                if (!Utils::FileSystem::removeFile(mediaFile))
                    continue;
                // Trim now-empty parent dirs, bounded by systemMediaDir.
                std::string parentPath {Utils::FileSystem::getParent(mediaFile)};
                while (parentPath.find(systemMediaDir) == 0 && parentPath != systemMediaDir) {
                    if (Utils::FileSystem::getDirContent(parentPath).size() == 0) {
                        Utils::FileSystem::removeDirectory(parentPath, false);
                        parentPath = Utils::FileSystem::getParent(parentPath);
                    }
                    else {
                        break;
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- scraper mappings

    std::string mapMediaSubdirToESStyle(const std::string& esdeSubdir)
    {
        if (esdeSubdir == "screenshots") return "images";
        if (esdeSubdir == "covers")      return "thumbnails";
        if (esdeSubdir == "marquees")    return "marquees";
        if (esdeSubdir == "videos")      return "videos";
        if (esdeSubdir == "fanart")      return "fanart";
        if (esdeSubdir == "manuals")     return "manuals";
        return esdeSubdir;
    }

    std::string mapMediaSubdirToMDKey(const std::string& esdeSubdir)
    {
        if (esdeSubdir == "screenshots") return "image";
        if (esdeSubdir == "covers")      return "thumbnail";
        if (esdeSubdir == "marquees")    return "marquee";
        if (esdeSubdir == "videos")      return "video";
        if (esdeSubdir == "fanart")      return "fanart";
        if (esdeSubdir == "manuals")     return "manual";
        return "";
    }

    void updateMetadataRelativePath(FileData* game,
                                    const std::string& mdKey,
                                    const std::string& startPath,
                                    const std::string& filePath)
    {
        if (!isEnabled() || mdKey.empty() || game == nullptr)
            return;

        std::string relPath {filePath};
        if (!startPath.empty()) {
            std::string normalized {Utils::String::replace(filePath, "\\", "/")};
            std::string normalizedStart {Utils::String::replace(startPath, "\\", "/")};
            if (!normalizedStart.empty() && normalizedStart.back() != '/')
                normalizedStart.append("/");
            if (normalized.find(normalizedStart) == 0)
                relPath = "./" + normalized.substr(normalizedStart.length());
        }
        game->metadata.set(mdKey, relPath);
    }
} // namespace Legacy
