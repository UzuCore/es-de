//  SPDX-License-Identifier: MIT
//
//  ES-DE Frontend
//  GuiRomDirectories.h
//
//  ROM directories management GUI.
//  Allows adding/removing multiple ROM directories.
//  When duplicate systems exist across directories, the earlier-registered
//  directory takes precedence.
//
// === LEGACY PATCH BEGIN === (멀티 롬디렉토리 GUI)

#ifndef ES_APP_GUIS_GUI_ROM_DIRECTORIES_H
#define ES_APP_GUIS_GUI_ROM_DIRECTORIES_H

#include "GuiComponent.h"
#include "components/MenuComponent.h"
#include "renderers/Renderer.h"

#include <string>
#include <vector>

class GuiRomDirectories : public GuiComponent
{
public:
    GuiRomDirectories();
    virtual ~GuiRomDirectories();

    bool input(InputConfig* config, Input input) override;
    std::vector<HelpPrompt> getHelpPrompts() override;

private:
    // Load current directory list from Settings (ROMDirectory + ROMDirectoryAdditional).
    void loadDirectories();

    // Save current directory list to Settings (first => ROMDirectory, rest joined by ';').
    void saveDirectories();

    // Rebuild the menu rows from mDirectories.
    void rebuildMenu();

    // Open the text-edit popup to add a new directory.
    void promptAddDirectory();

    // Open the text-edit popup to edit an existing directory.
    void promptEditDirectory(size_t index);

    // Remove a directory entry (with confirmation).
    void promptRemoveDirectory(size_t index);

    // Show the "restart required" message box when settings have changed.
    void showRestartMessage();

    Renderer* mRenderer;
    MenuComponent mMenu;

    // Current list of ROM directories (in priority order; earlier = higher priority).
    std::vector<std::string> mDirectories;

    // Snapshot of mDirectories at construction time, used to detect changes on close.
    std::vector<std::string> mInitialDirectories;
};

#endif // ES_APP_GUIS_GUI_ROM_DIRECTORIES_H

// === LEGACY PATCH END ===
