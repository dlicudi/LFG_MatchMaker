# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# LFG MatchMaker Continued - Architecture Guide

## Project Overview

**LFG MatchMaker Continued** is a World of Warcraft addon that automates the process of finding dungeon groups by monitoring chat channels and matching players based on their dungeon preferences. It's a continuation/fork of the original LFG MatchMaker addon, specifically updated for WoW Classic Era.

### Key Features
- **Chat Monitoring**: Automatically parses LookingForGroup, General, and Trade channels for LFG/LFM messages
- **Pattern Matching**: Recognizes dungeon names in multiple languages and various spellings/misspellings
- **Smart Notifications**: Shows popup notifications when matching groups are found
- **Broadcasting**: Allows players to automatically broadcast their own LFG/LFM messages
- **Group Management**: Automatically stops searches when group size requirements are met

## Project Type & Structure

This is a **World of Warcraft Addon** built for WoW Classic Era (Interface version 11503). The project follows standard WoW addon conventions with:

- `.toc` file for addon metadata and load order
- Lua scripts for game logic
- XML files for UI definition
- External libraries for common functionality

## Architecture Overview

### Core Files & Entry Points

#### Main Entry Point
- **`LFG_MatchMaker_Continued.toc`**: Addon metadata and file load order definition
- **`LFGMM_Core.lua`** (877 lines): Primary initialization and event handling system

#### UI Definition
- **`LFGMM_Interface.xml`**: XML-based UI frame definitions
- **`LFGMM_Interface.lua`** (68 lines): UI initialization and property setup

#### Data & Configuration
- **`LFGMM_Variables.lua`** (2535 lines): Massive file containing all dungeon data, identifiers, and database schema

### Modular Components

The addon follows a modular tab-based architecture:

#### Tab Components (UI Modules)
- **`LFGMM_LfgTab.lua`** (616 lines): "Looking for Group" search interface
- **`LFGMM_LfmTab.lua`** (493 lines): "Looking for More" group leader interface  
- **`LFGMM_ListTab.lua`** (857 lines): Message history and filtering interface
- **`LFGMM_SettingsTab.lua`** (325 lines): Configuration and preferences

#### Utility Components
- **`LFGMM_Utility.lua`** (621 lines): Helper functions for UI, data manipulation, and common operations
- **`LFGMM_MinimapButton.lua`** (90 lines): Minimap integration using LibDBIcon
- **`LFGMM_PopupWindow.lua`** (375 lines): Match notification popup system
- **`LFGMM_BroadcastWindow.lua`** (144 lines): Message broadcasting interface

### External Dependencies

#### Libraries (in `/Libs/` directory)
- **LibStub**: Library loading and version management
- **CallbackHandler-1.0**: Event callback system
- **LibDataBroker-1.1**: Data sharing between addons
- **LibDBIcon-1.0**: Minimap button management

These are standard WoW addon libraries that provide cross-addon compatibility and UI functionality.

## Key Architectural Patterns

### Event-Driven Architecture
The addon uses WoW's event system extensively:
- `PLAYER_ENTERING_WORLD`: Initial setup and player data loading
- `CHAT_MSG_CHANNEL`: Real-time chat message parsing
- `GROUP_ROSTER_UPDATE`: Automatic search stopping when groups form
- `ZONE_CHANGED_NEW_AREA`: Channel re-joining on zone changes

### Data-Driven Design
- **Dungeon Database**: Comprehensive dungeon data with multilingual identifiers stored in `LFGMM_Variables.lua`
- **Pattern Matching**: Extensive regex patterns for recognizing dungeon names and group types
- **Localization**: Support for English, German, French, and Spanish identifiers

### Tab-Based UI Pattern
Each tab is a self-contained module with its own:
- Initialization function
- Show/Hide logic
- Refresh functionality
- Event handlers

### Saved Variables System
Uses WoW's `SavedVariablesPerCharacter` system for persistent storage:
- Search preferences
- UI settings
- Broadcast templates
- Filter configurations

## Development Workflow

### File Loading Order (from .toc)
1. **Libraries**: External dependencies loaded first
2. **Core Infrastructure**: Interface XML and Lua initialization
3. **Core Logic**: Main event handling and utility functions
4. **UI Components**: Tab modules loaded in logical order
5. **Data**: Variable definitions loaded last

### Development Commands
This is a direct-deployment addon with no build system:
- **Testing**: Copy files to `World of Warcraft/_classic_era_/Interface/AddOns/LFG_MatchMaker_Continued/` and restart WoW
- **In-game access**: Use slash commands `/lfgmm`, `/lfgmatchmaker`, or `/matchmaker` to open the addon
- **Error debugging**: Use `/console scriptErrors 1` in WoW to see Lua errors
- **Version updating**: Modify version in `LFG_MatchMaker_Continued.toc` header
- **Distribution**: Copy all files (excluding those in .gitignore) to a zip file for distribution

### Error Handling & Debugging
The addon uses defensive coding for player class access but allows Lua errors to bubble up for proper debugging with full stack traces. Use `/console scriptErrors 1` in WoW to see all errors.

### No Build Process
- Files are loaded directly by WoW client  
- No compilation or bundling required
- No package managers or dependencies beyond included libraries

### Development Conventions
- **Function Naming**: All functions prefixed with `LFGMM_` + module name
- **Global Namespace**: Uses `LFGMM_GLOBAL` and `LFGMM_DB` for state
- **Event Handling**: Centralized in `LFGMM_Core_EventHandler`
- **UI Updates**: Each module has its own refresh function

## Data Flow

### Message Processing Pipeline
1. **Chat Event**: `CHAT_MSG_CHANNEL` triggers in Core
2. **Text Processing**: Message normalized (accents removed, items stripped)
3. **Pattern Matching**: Dungeon and group type identification
4. **Storage**: Message stored in `LFGMM_GLOBAL.MESSAGES` table
5. **Search Matching**: Active searches checked for matches
6. **UI Updates**: All relevant tabs refreshed

### Search System
1. **Configuration**: User selects dungeons and preferences
2. **Activation**: Search flag set in database
3. **Monitoring**: Core processes incoming messages
4. **Matching**: Messages compared against search criteria
5. **Notification**: Popup shown for matches
6. **Actions**: User can ignore, whisper, invite, or request invite

## Key Technical Features

### Multilingual Support
- Pattern matching supports 4 languages with extensive dungeon name variations
- Handles common misspellings and abbreviations
- Removes "/w me" patterns in multiple languages to prevent false matches

### Smart Group Detection
- Automatically detects group composition changes
- Stops LFG searches when player joins a group
- Stops LFM searches when group reaches dungeon capacity

### Rate Limiting & Cooldowns
- 5-second cooldown on `/who` requests to prevent spam
- Configurable broadcast intervals
- Message age filtering (default 10-30 minutes)

### Memory Management
- Automatic cleanup of messages older than 30 minutes
- Prevents memory leaks from long gaming sessions

## File Dependencies

The load order in the .toc file is critical:
1. Libraries must load before core files
2. Interface.xml must load before Interface.lua
3. Core.lua must load before tab modules
4. Variables.lua loads last to ensure all functions are available

## Integration Points

### WoW API Usage
- **Chat System**: `SendChatMessage`, channel monitoring
- **Group System**: `InviteUnit`, `UnitName` for party/raid info
- **UI System**: Custom frames, dropdowns, checkboxes
- **Storage**: `SavedVariablesPerCharacter` for persistence

### External Integrations
- **Quest Log**: Adds button to quest log window
- **Minimap**: LibDBIcon integration for minimap button
- **Party Invites**: Hooks into WoW's party invite dialog system

## Performance Considerations

### Optimization Strategies
- **Event Filtering**: Only processes relevant chat channels
- **Pattern Caching**: Dungeon patterns pre-compiled at startup
- **UI Refreshing**: Conditional refreshes only when tabs are visible
- **Memory Cleanup**: Regular cleanup of old messages and state

### Scalability
The addon is designed for individual player use and scales well with:
- Large numbers of chat messages (efficient pattern matching)
- Multiple dungeon selections (indexed lookups)
- Extended play sessions (automatic cleanup)

## Development Guidelines

### Working with this Codebase
1. **Understand the Event Flow**: Start with `LFGMM_Core_EventHandler`
2. **Follow Naming Conventions**: All functions are module-prefixed
3. **Test Chat Parsing**: The core feature is message pattern matching
4. **UI Updates**: Each change should trigger appropriate refresh functions
5. **Data Integrity**: Maintain compatibility with saved variables schema

### Common Tasks
- **Adding Dungeons**: Modify `LFGMM_Variables.lua` dungeon data
- **UI Changes**: Update both XML and corresponding Lua modules
- **New Features**: Follow the tab-based module pattern
- **Bug Fixes**: Often involve pattern matching or event handling logic

This addon represents a mature, well-structured WoW addon with sophisticated chat parsing, multilingual support, and a clean modular architecture suitable for ongoing development and maintenance.