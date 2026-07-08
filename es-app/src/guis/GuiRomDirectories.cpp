//  SPDX-License-Identifier: MIT
//
//  ES-DE Frontend
//  GuiRomDirectories.cpp
//
//  ROM directories management GUI.
//  Allows adding/removing/reordering multiple ROM directories.
//
//  Behavior:
//    - The first entry in the list is stored in the "ROMDirectory" setting
//      (preserving compatibility with %ROMPATH% expansion and the rest of the
//      codebase that reads this single value).
//    - Additional entries (entry index >= 1) are stored in
//      "ROMDirectoryAdditional" as a ';' separated list, in priority order.
//    - When a system (by <name>) is found in more than one of these
//      directories, the earlier-registered directory wins.
//
// === LEGACY PATCH BEGIN === (멀티 롬디렉토리 GUI)

#include "guis/GuiRomDirectories.h"

#include "FileData.h"
#include "Settings.h"
#include "Window.h"
#include "components/ButtonComponent.h"
#include "components/TextComponent.h"
#include "guis/GuiMsgBox.h"
#include "guis/GuiTextEditKeyboardPopup.h"
#include "guis/GuiTextEditPopup.h"
#include "utils/FileSystemUtil.h"
#include "utils/LocalizationUtil.h"
#include "utils/StringUtil.h"
#include "views/ViewController.h"

namespace
{
    // Split a ';' separated list, trimming each element. Empty elements are
    // dropped so that trailing/leading separators are harmless.
    std::vector<std::string> splitSemicolonList(const std::string& joined)
    {
        std::vector<std::string> out;
        size_t start {0};
        while (start <= joined.size()) {
            size_t end {joined.find(';', start)};
            if (end == std::string::npos)
                end = joined.size();
            std::string piece {joined.substr(start, end - start)};
            piece = Utils::String::trim(piece);
            if (!piece.empty())
                out.emplace_back(piece);
            if (end == joined.size())
                break;
            start = end + 1;
        }
        return out;
    }

    std::string joinSemicolonList(const std::vector<std::string>& parts)
    {
        std::string out;
        for (size_t i {0}; i < parts.size(); ++i) {
            if (i != 0)
                out += ";";
            out += parts[i];
        }
        return out;
    }

    // Display-friendly form of a path (uses backslashes on Windows).
    std::string displayPath(const std::string& p)
    {
#if defined(_WIN64)
        return Utils::String::replace(p, "/", "\\");
#else
        return p;
#endif
    }
} // namespace

GuiRomDirectories::GuiRomDirectories()
    : mRenderer {Renderer::getInstance()}
    , mMenu {_("ROM DIRECTORIES")}
{
    addChild(&mMenu);

    loadDirectories();
    mInitialDirectories = mDirectories;

    // Build the directory rows (rebuildMenu only manages the list rows,
    // it does NOT add buttons — those are added once below).
    rebuildMenu();

    // Buttons row at the bottom of the menu.
    mMenu.addButton(_("ADD DIRECTORY"), _("add a new rom directory"),
                    [this] { promptAddDirectory(); });

    mMenu.addButton(_("BACK"), _("back"), [this] { delete this; });

    setSize(Renderer::getScreenWidth(), Renderer::getScreenHeight());
    mMenu.setPosition((mSize.x - mMenu.getSize().x) / 2.0f, Renderer::getScreenHeight() * 0.13f);
}

GuiRomDirectories::~GuiRomDirectories()
{
    // If anything changed compared to the snapshot we took at open time,
    // persist the settings and prompt the user to restart so SystemData can
    // rescan from scratch.
    if (mDirectories != mInitialDirectories) {
        saveDirectories();
        showRestartMessage();
    }
}

void GuiRomDirectories::loadDirectories()
{
    mDirectories.clear();

    const std::string& main {Settings::getInstance()->getString("ROMDirectory")};
    if (!Utils::String::trim(main).empty())
        mDirectories.emplace_back(Utils::String::trim(main));

    const std::string& extra {Settings::getInstance()->getString("ROMDirectoryAdditional")};
    for (const auto& d : splitSemicolonList(extra))
        mDirectories.emplace_back(d);
}

void GuiRomDirectories::saveDirectories()
{
    if (mDirectories.empty()) {
        // Clearing everything resets to the hardcoded default (~/ROMs/).
        Settings::getInstance()->setString("ROMDirectory", "");
        Settings::getInstance()->setString("ROMDirectoryAdditional", "");
    }
    else {
        Settings::getInstance()->setString("ROMDirectory", mDirectories.front());
        if (mDirectories.size() > 1) {
            std::vector<std::string> rest {mDirectories.begin() + 1, mDirectories.end()};
            Settings::getInstance()->setString("ROMDirectoryAdditional", joinSemicolonList(rest));
        }
        else {
            Settings::getInstance()->setString("ROMDirectoryAdditional", "");
        }
    }
    Settings::getInstance()->saveFile();
}

void GuiRomDirectories::rebuildMenu()
{
    // Clear the existing list rows; buttons are managed separately and stay.
    mMenu.getList()->clear();

    const float fontSize {FONT_SIZE_MEDIUM};
    const float rowPriorityWidth {mMenu.getSize().x / 8.0f};

    if (mDirectories.empty()) {
        // Friendly hint when the list is empty.
        ComponentListRow row;
        auto hint = std::make_shared<TextComponent>(
            ViewController::EXCLAMATION_CHAR + "  " +
                _("NO ROM DIRECTORIES CONFIGURED (DEFAULT WILL BE USED)"),
            Font::get(fontSize), mMenuColorPrimary, ALIGN_CENTER);
        row.addElement(hint, true);
        mMenu.addRow(row);
        return;
    }

    // One row per directory. Tapping a row opens an action sheet (edit / remove).
    for (size_t i {0}; i < mDirectories.size(); ++i) {
        ComponentListRow row;

        // Priority label on the left ("1." "2." ...).
        const std::string priorityLabel {std::to_string(i + 1) + "."};
        auto priorityText = std::make_shared<TextComponent>(
            priorityLabel, Font::get(fontSize, FONT_PATH_BOLD), mMenuColorPrimary, ALIGN_LEFT,
            ALIGN_CENTER, glm::ivec2 {0, 0});
        priorityText->setSize(rowPriorityWidth, priorityText->getSize().y);
        row.addElement(priorityText, false);

        // The path itself, left aligned right next to the priority number.
        auto pathText = std::make_shared<TextComponent>(
            displayPath(mDirectories[i]), Font::get(fontSize, FONT_PATH_LIGHT), mMenuColorPrimary,
            ALIGN_LEFT, ALIGN_CENTER, glm::ivec2 {0, 0});
        pathText->setSize(mMenu.getSize().x - rowPriorityWidth -
                              20.0f * Renderer::getScreenHeightModifier(),
                          pathText->getSize().y);
        row.addElement(pathText, false);

        const size_t indexCopy {i};
        row.makeAcceptInputHandler([this, indexCopy] {
            // Per-entry action menu: EDIT / REMOVE / CANCEL.
            mWindow->pushGui(new GuiMsgBox(
                _("CHOOSE AN ACTION"),
                _("EDIT"), [this, indexCopy] { promptEditDirectory(indexCopy); },
                _("REMOVE"), [this, indexCopy] { promptRemoveDirectory(indexCopy); },
                _("CANCEL"), nullptr));
        });

        mMenu.addRow(row);
    }
}

void GuiRomDirectories::promptAddDirectory()
{
    auto savedHandler = [this](const std::string& newPath) {
        std::string trimmed {Utils::String::trim(newPath)};
        if (trimmed.empty())
            return;

#if defined(_WIN64)
        // Normalize backslashes to forward slashes for internal storage.
        trimmed = Utils::String::replace(trimmed, "\\", "/");
#endif

        // Prevent duplicates (case-sensitive comparison; users entering the
        // same path with different casing on case-insensitive filesystems are
        // out of scope here).
        for (const auto& existing : mDirectories) {
            if (existing == trimmed) {
                mWindow->pushGui(new GuiMsgBox(_("THIS DIRECTORY IS ALREADY IN THE LIST"),
                                               _("OK"), nullptr));
                return;
            }
        }

        mDirectories.emplace_back(trimmed);
        rebuildMenu();
    };

    const std::string emptyInit;
    if (Settings::getInstance()->getBool("VirtualKeyboard")) {
        mWindow->pushGui(new GuiTextEditKeyboardPopup(
            mMenu.getPosition().y, _("ENTER ROM DIRECTORY PATH"), emptyInit, savedHandler, false,
            _("SAVE"), _("SAVE CHANGES?"), "", "", _("LOAD DEFAULT"), _("CLEAR")));
    }
    else {
        mWindow->pushGui(new GuiTextEditPopup(_("ENTER ROM DIRECTORY PATH"), emptyInit,
                                              savedHandler, false, _("SAVE"), _("SAVE CHANGES?"),
                                              "", "", _("LOAD DEFAULT"), _("CLEAR")));
    }
}

void GuiRomDirectories::promptEditDirectory(size_t index)
{
    if (index >= mDirectories.size())
        return;

    const std::string current {mDirectories[index]};

    auto savedHandler = [this, index](const std::string& newPath) {
        std::string trimmed {Utils::String::trim(newPath)};
#if defined(_WIN64)
        trimmed = Utils::String::replace(trimmed, "\\", "/");
#endif

        if (trimmed.empty()) {
            // An empty edit is treated as a removal.
            if (index < mDirectories.size())
                mDirectories.erase(mDirectories.begin() + index);
            rebuildMenu();
            return;
        }

        // Check duplicates against other entries only.
        for (size_t i {0}; i < mDirectories.size(); ++i) {
            if (i == index)
                continue;
            if (mDirectories[i] == trimmed) {
                mWindow->pushGui(new GuiMsgBox(_("THIS DIRECTORY IS ALREADY IN THE LIST"),
                                               _("OK"), nullptr));
                return;
            }
        }

        if (index < mDirectories.size())
            mDirectories[index] = trimmed;
        rebuildMenu();
    };

    const std::string initValue {displayPath(current)};
    if (Settings::getInstance()->getBool("VirtualKeyboard")) {
        mWindow->pushGui(new GuiTextEditKeyboardPopup(
            mMenu.getPosition().y, _("ENTER ROM DIRECTORY PATH"), initValue, savedHandler, false,
            _("SAVE"), _("SAVE CHANGES?"), _("Currently configured path:"), initValue,
            _("LOAD CURRENTLY CONFIGURED PATH"), _("CLEAR (LEAVE BLANK TO REMOVE THIS ENTRY)")));
    }
    else {
        mWindow->pushGui(new GuiTextEditPopup(
            _("ENTER ROM DIRECTORY PATH"), initValue, savedHandler, false, _("SAVE"),
            _("SAVE CHANGES?"), _("Currently configured path:"), initValue,
            _("LOAD CURRENTLY CONFIGURED PATH"), _("CLEAR (LEAVE BLANK TO REMOVE THIS ENTRY)")));
    }
}

void GuiRomDirectories::promptRemoveDirectory(size_t index)
{
    if (index >= mDirectories.size())
        return;

    const std::string display {displayPath(mDirectories[index])};

    mWindow->pushGui(new GuiMsgBox(
        _("REMOVE THIS ROM DIRECTORY?") + std::string("\n\n") + display, _("YES"),
        [this, index] {
            if (index < mDirectories.size()) {
                mDirectories.erase(mDirectories.begin() + index);
                rebuildMenu();
            }
        },
        _("NO"), nullptr));
}

void GuiRomDirectories::showRestartMessage()
{
    mWindow->pushGui(new GuiMsgBox(
        _("ROM DIRECTORY SETTING SAVED, RESTART THE APPLICATION TO RESCAN THE SYSTEMS"), _("OK"),
        nullptr, "", nullptr, "", nullptr, "", nullptr, nullptr, true, true,
        (mRenderer->getIsVerticalOrientation() ?
             0.66f :
             0.42f * (1.778f / mRenderer->getScreenAspectRatio()))));
}

bool GuiRomDirectories::input(InputConfig* config, Input input)
{
    if (GuiComponent::input(config, input))
        return true;

    // Back button closes the GUI (the destructor handles save + restart prompt).
    if (input.value != 0 && config->isMappedTo("b", input)) {
        delete this;
        return true;
    }

    return false;
}

std::vector<HelpPrompt> GuiRomDirectories::getHelpPrompts()
{
    std::vector<HelpPrompt> prompts {mMenu.getHelpPrompts()};
    prompts.push_back(HelpPrompt("b", _("back")));
    return prompts;
}

// === LEGACY PATCH END ===
