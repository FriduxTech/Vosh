//
//  VoshAgent.swift
//  Vosh
//
//  Created by Vosh Team.
//

import Access
import AppKit
import AVFoundation
import Cocoa
import Element
import Input
import Output

/// The central controller bridging User Input, Screen Reading logic (`Access`), and Feedback (`Output`).
///
/// `VoshAgent` orchestrates the accessibility experience by:
/// 1. Managing the `Access` framework instance for screen reader capabilities.
/// 2. Binding keyboard/gesture commands to semantic actions via `Input`.
/// 3. Handling focus management, command dispatch, and interaction modes (e.g., Browse Mode, Rotor).
/// 4. Coordinating visual highlights (Focus Ring, Speech Viewer) and audio feedback.
@MainActor final class VoshAgent {
    
    // MARK: - Core Components
    
    // Type alias to resolve Element if module import fails
    // typealias Element = Access.Element // Access doesn't export it? 
    // We'll try just using Any for now or rely on type inference if possible.
    
    /// Handle to the underlying `Access` framework for accessibility tree interaction.
    private let accessibility: Access
    
    /// Tracking dictionary for key press timestamps, used for double-press detection.
    private var lastPressTimes = [InputKeyCode: UInt64]()
    
    // MARK: - Command System
    
    /// Threshold in nanoseconds for detecting double-press actions (500ms).
    private let doublePressThreshold: UInt64 = 500_000_000
    
    /// Enumeration of all executable commands in Vosh.
    public enum VoshCommand: String, CaseIterable, Codable {
        // MARK: - General Actions
        case voshMenu, quit, toggleSpeech, toggleScreenCurtain, settings
        case notificationCenter, controlCenter, inputHelp, passNextKey
        case escape
        
        // MARK: - Navigation
        case nextItem, previousItem, parent, firstChild
        case rotorUp, rotorDown, rotorNext, rotorPrevious
        
        // MARK: - Browse Mode / Web
        case toggleBrowseMode, find, findNext
        case listLinks, listHeadings, listWindows, listApplications
        case browseNextHeading, browsePreviousHeading
        case browseNextLink, browsePreviousLink
        case browseNextButton, browsePreviousButton
        case browseNextEditField, browsePreviousEditField
        case browseNextQuote, browsePreviousQuote
        case browseNextTable, browsePreviousTable
        case browseNextLandmark, browsePreviousLandmark
        case browseNextForm, browsePreviousForm
        
        // MARK: - Reading
        case readWindow, readEntireWindow, readFromTop, readFromCursor, readClipboard, readTimeDate
        case readLine, spellLine, readWord, spellWord, readCharacter, readPhonetic

        case describeImage, ocrScreen, askVosh
        case copyLastSpoken, readTextAttributes
        case readSelection
        case announceContext, historyPrevious, historyNext
        
        // MARK: - Mouse Control
        case moveMouseToFocus, moveMouseAndClick
        
        // MARK: - Review Cursor (Virtual Navigation)
        case moveReviewNext, moveReviewPrev, moveReviewParent, moveReviewChild
        case toggleReviewFollowsFocus, toggleFocusFollowsReview
        case moveMouseToReviewFocus, moveReviewFocusToMouse
        
        // MARK: - Tool toggles
        case toggleSpeechViewer
        case toggleInputHelpMode
        
        // MARK: - System
        case menuBar, windowMenu, contextMenu, dock, applicationName, windowTitle
        
        // MARK: - Interaction
        case activate // Enter/Click
    }
    
    // MARK: - Command Execution
    
    // MARK: - Command Execution
    
    /// Executes a specific Vosh command.
    /// - Parameter command: The command to perform.
    private func perform(_ command: VoshCommand) async {
        await CommandRegistry.shared.execute(command.rawValue, agent: self)
    }
    
    /// Registers all standard Vosh commands.
    private func setupCommands() {
        let reg = CommandRegistry.shared
        
        // General
        reg.register(BlockCommand { agent in await agent.openVoshMenu() }, for: VoshCommand.voshMenu.rawValue)
        reg.register(BlockCommand { agent in await agent.quitVosh() }, for: VoshCommand.quit.rawValue)
        reg.register(BlockCommand { agent in await agent.toggleSpeech() }, for: VoshCommand.toggleSpeech.rawValue)
        reg.register(BlockCommand { agent in await agent.toggleScreenCurtain() }, for: VoshCommand.toggleScreenCurtain.rawValue)
        reg.register(BlockCommand { agent in await agent.openSettings() }, for: VoshCommand.settings.rawValue)
        reg.register(BlockCommand { agent in await agent.accessNotificationCenter() }, for: VoshCommand.notificationCenter.rawValue)
        reg.register(BlockCommand { agent in await agent.accessControlCenter() }, for: VoshCommand.controlCenter.rawValue)
        reg.register(BlockCommand { agent in await agent.toggleInputHelpMode() }, for: VoshCommand.inputHelp.rawValue)
        reg.register(BlockCommand { agent in await agent.passNextKey() }, for: VoshCommand.passNextKey.rawValue)
        reg.register(BlockCommand { agent in await agent.handleEscape() }, for: VoshCommand.escape.rawValue)
        
        // Navigation
        reg.register(BlockCommand { agent in agent.performNavigation { a in await a.accessibility.focusNextSibling(backwards: false) } }, for: VoshCommand.nextItem.rawValue)
        reg.register(BlockCommand { agent in agent.performNavigation { a in await a.accessibility.focusNextSibling(backwards: true) } }, for: VoshCommand.previousItem.rawValue)
        reg.register(BlockCommand { agent in agent.performNavigation { a in await a.accessibility.focusParent() } }, for: VoshCommand.parent.rawValue)
        reg.register(BlockCommand { agent in agent.performNavigation { a in await a.accessibility.focusFirstChild() } }, for: VoshCommand.firstChild.rawValue)
        reg.register(BlockCommand { agent in agent.performNavigation { a in await a.handleRotorUp() } }, for: VoshCommand.rotorUp.rawValue)
        reg.register(BlockCommand { agent in agent.performNavigation { a in await a.handleRotorDown() } }, for: VoshCommand.rotorDown.rawValue)
        reg.register(BlockCommand { agent in agent.selector.next() }, for: VoshCommand.rotorNext.rawValue)
        reg.register(BlockCommand { agent in agent.selector.previous() }, for: VoshCommand.rotorPrevious.rawValue)
        
        // Reading
        reg.register(BlockCommand { agent in await agent.readEntireWindow() }, for: VoshCommand.readWindow.rawValue)
        reg.register(BlockCommand { agent in await agent.readEntireWindow() }, for: VoshCommand.readEntireWindow.rawValue) // Alias
        reg.register(BlockCommand { agent in await agent.readEntireWindow() }, for: VoshCommand.readFromTop.rawValue) 
        reg.register(BlockCommand { agent in await agent.readFromCursor() }, for: VoshCommand.readFromCursor.rawValue)
        reg.register(BlockCommand { agent in await agent.readClipboard() }, for: VoshCommand.readClipboard.rawValue)
        reg.register(BlockCommand { agent in await agent.readTimeDate() }, for: VoshCommand.readTimeDate.rawValue)
        
        reg.register(BlockCommand { agent in await agent.readCurrentLine() }, for: VoshCommand.readLine.rawValue)
        reg.register(BlockCommand { agent in await agent.spellCurrentLine() }, for: VoshCommand.spellLine.rawValue)
        reg.register(BlockCommand { agent in await agent.readCurrentWord() }, for: VoshCommand.readWord.rawValue)
        reg.register(BlockCommand { agent in await agent.spellCurrentWord() }, for: VoshCommand.spellWord.rawValue)
        reg.register(BlockCommand { agent in await agent.readCurrentCharacter() }, for: VoshCommand.readCharacter.rawValue)
        reg.register(BlockCommand { agent in await agent.readCurrentCharacterPhonetically() }, for: VoshCommand.readPhonetic.rawValue)
        
        reg.register(BlockCommand { agent in await agent.describeImage() }, for: VoshCommand.describeImage.rawValue)
        reg.register(BlockCommand { agent in await agent.ocrScreen() }, for: VoshCommand.ocrScreen.rawValue)
        reg.register(BlockCommand { [unowned self] _ in await self.askVosh() }, for: VoshCommand.askVosh.rawValue)
        
        reg.register(BlockCommand { _ in
            if let text = Output.shared.lastSpoken {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                Output.shared.announce("Copied: \(text)")
            } else {
                Output.shared.announce("Nothing to copy")
            }
        }, for: VoshCommand.copyLastSpoken.rawValue)
        
        reg.register(BlockCommand { agent in 
            await agent.accessibility.readTextAttributes() 
        }, for: VoshCommand.readTextAttributes.rawValue)

        reg.register(BlockCommand { agent in await agent.readSelection() }, for: VoshCommand.readSelection.rawValue)

        reg.register(BlockCommand { agent in 
            let context = await agent.accessibility.getContextDescription()
            Output.shared.announce(context)
        }, for: VoshCommand.announceContext.rawValue)
        
        reg.register(BlockCommand { _ in Output.shared.readPreviousHistory() }, for: VoshCommand.historyPrevious.rawValue)
        reg.register(BlockCommand { _ in Output.shared.readNextHistory() }, for: VoshCommand.historyNext.rawValue)
        
        // Mouse
        reg.register(BlockCommand { agent in await agent.moveMouseToFocus() }, for: VoshCommand.moveMouseToFocus.rawValue)
        reg.register(BlockCommand { agent in await agent.moveMouseAndClick() }, for: VoshCommand.moveMouseAndClick.rawValue)
        
        // System
        reg.register(BlockCommand { agent in await agent.accessMenuBar() }, for: VoshCommand.menuBar.rawValue)
        reg.register(BlockCommand { agent in await agent.accessWindowMenu() }, for: VoshCommand.windowMenu.rawValue)
        reg.register(BlockCommand { agent in await agent.accessContextMenu() }, for: VoshCommand.contextMenu.rawValue)
        reg.register(BlockCommand { agent in await agent.accessDock() }, for: VoshCommand.dock.rawValue)
        reg.register(BlockCommand { agent in await agent.announceApplicationName() }, for: VoshCommand.applicationName.rawValue)
        reg.register(BlockCommand { agent in await agent.announceWindowTitle() }, for: VoshCommand.windowTitle.rawValue)
        reg.register(BlockCommand { agent in await agent.listWindows() }, for: VoshCommand.listWindows.rawValue)
        reg.register(BlockCommand { agent in await agent.listApplications() }, for: VoshCommand.listApplications.rawValue)
        
        // Web
        reg.register(BlockCommand { agent in await agent.toggleBrowseMode() }, for: VoshCommand.toggleBrowseMode.rawValue)
        reg.register(BlockCommand { agent in await agent.openFindDialog() }, for: VoshCommand.find.rawValue)
        reg.register(BlockCommand { agent in await agent.findNext() }, for: VoshCommand.findNext.rawValue)
        reg.register(BlockCommand { agent in await agent.listLinks() }, for: VoshCommand.listLinks.rawValue)
        reg.register(BlockCommand { agent in await agent.listHeadings() }, for: VoshCommand.listHeadings.rawValue)
        
        // Dynamic Browse Commands
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "Heading") }, for: VoshCommand.browseNextHeading.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "Heading") }, for: VoshCommand.browsePreviousHeading.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "Link") }, for: VoshCommand.browseNextLink.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "Link") }, for: VoshCommand.browsePreviousLink.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "Button") }, for: VoshCommand.browseNextButton.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "Button") }, for: VoshCommand.browsePreviousButton.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "EditField") }, for: VoshCommand.browseNextEditField.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "EditField") }, for: VoshCommand.browsePreviousEditField.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "Blockquote") }, for: VoshCommand.browseNextQuote.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "Blockquote") }, for: VoshCommand.browsePreviousQuote.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "Table") }, for: VoshCommand.browseNextTable.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "Table") }, for: VoshCommand.browsePreviousTable.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "Group") }, for: VoshCommand.browseNextLandmark.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "Group") }, for: VoshCommand.browsePreviousLandmark.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browseNextElement(role: "TextField") }, for: VoshCommand.browseNextForm.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.browsePreviousElement(role: "TextField") }, for: VoshCommand.browsePreviousForm.rawValue)
        
        // Review Cursor
        reg.register(BlockCommand { agent in await agent.accessibility.moveReviewFocusNext() }, for: VoshCommand.moveReviewNext.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.moveReviewFocusNext(backwards: true) }, for: VoshCommand.moveReviewPrev.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.moveReviewFocusParent() }, for: VoshCommand.moveReviewParent.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.moveReviewFocusChild() }, for: VoshCommand.moveReviewChild.rawValue)
        
        reg.register(BlockCommand { agent in
            Task { @AccessActor in agent.accessibility.reviewFollowsFocus.toggle() }
            await Output.shared.announce("Review follows focus: \(agent.accessibility.reviewFollowsFocus ? "On" : "Off")")
        }, for: VoshCommand.toggleReviewFollowsFocus.rawValue)
        
        reg.register(BlockCommand { agent in
            Task { @AccessActor in agent.accessibility.focusFollowsReview.toggle() }
            await Output.shared.announce("Focus follows review: \(agent.accessibility.focusFollowsReview ? "On" : "Off")")
        }, for: VoshCommand.toggleFocusFollowsReview.rawValue)
        
        reg.register(BlockCommand { agent in await agent.accessibility.moveMouseToReviewFocus() }, for: VoshCommand.moveMouseToReviewFocus.rawValue)
        reg.register(BlockCommand { agent in await agent.accessibility.moveReviewFocusToMouse() }, for: VoshCommand.moveReviewFocusToMouse.rawValue)
        
        // Tools
        reg.register(BlockCommand { agent in
            guard let sv = agent.speechViewer else { return }
            if sv.isVisible {
                sv.orderOut(nil)
                Output.shared.announce("Speech Viewer Off")
            } else {
                sv.makeKeyAndOrderFront(nil)
                Output.shared.announce("Speech Viewer On")
            }
        }, for: VoshCommand.toggleSpeechViewer.rawValue)
        
        // Interaction
        reg.register(BlockCommand { agent in await agent.performActivate() }, for: VoshCommand.activate.rawValue)
    }
    
    /// Activates the currently focused element (Click/Press).
    ///
    /// Attempts to perform the default accessibility action (e.g., clicking a button).
    /// If AXPress fails or is unsupported, it falls back to simulating a Return key press.
    func performActivate() async {
        // 1. Try AXPress on the focused element
        if await accessibility.performActionOnFocus("AXPress") {
             return // Success
        }
        
        // 2. Fallback: Simulate Return Key
        await MainActor.run {
            let source = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: true) // Return
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x24, keyDown: false)
             
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }
    
    /// Opens the Settings window/menu.
    internal func openSettings() async {
        await MainActor.run {
             // If SettingsWindow is separate entity managed by App Delegate, we might need notification.
             // Or VoshAgent creates it? Usually App Delegate.
             // Just announce for now or use NSApp
             NSApp.activate(ignoringOtherApps: true)
             // Notification or direct call if possible.
             Output.shared.announce("Open Settings from Menu Bar") // Placeholder
        }
    }

    // MARK: - Setup
    
    /// Binds all Vosh commands to their default keyboard shortcuts.
    private func setupBindings() {
        // Clear existing? Input doesn't support clear yet.
        // Assuming clean start or idempotent overwrite.
        
        // 1. Initial Defaults (if keys empty)
        // Hardcoded defaults for MVP Phase 4 to ensure system works
        // Ideally we load from Preferences.keyMapping, if empty, populate with defaults.
        
        // Default Mapping
        bind(.voshMenu, key: .keyboardV)
        bind(.quit, key: .keyboardQ)
        bind(.toggleSpeech, key: .keyboardS)
        bind(.toggleScreenCurtain, key: .keyboardS, shift: true)
        
        // Context & History
        bind(.announceContext, key: .keyboardK, shift: true)
        bind(.historyPrevious, key: .keyboardLeftArrow, ctrl: true)
        bind(.historyNext, key: .keyboardRightArrow, ctrl: true)
        
        // Navigation
        bind(.nextItem, key: .keyboardRightArrow)
        bind(.previousItem, key: .keyboardLeftArrow)
        bind(.parent, key: .keyboardUpArrow, shift: true) // Using shift for parent/child to free Up/Down for rotor
        bind(.firstChild, key: .keyboardDownArrow, shift: true)
        
        bind(.rotorNext, key: .keyboardU)
        bind(.rotorPrevious, key: .keyboardU, shift: true)
        bind(.rotorUp, key: .keyboardUpArrow)
        bind(.rotorDown, key: .keyboardDownArrow)
        
        // Reading
        bind(.readWindow, key: .keyboardB)
        bind(.readFromCursor, key: .keyboardR)
        bind(.readTimeDate, key: .keyboardT)
        bind(.readClipboard, key: .keyboardC)
        bind(.askVosh, key: .keyboardA, shift: true, cmd: true) // Caps+Shift+Cmd+A? Or just Caps+Shift+A (clashes with App List?)
        // App List is Shift+A. Let's use Shift+Q ("Query")? or Shift+Slash?
        // Let's use Shift+Slash (Question Mark)
        bind(.askVosh, key: .keyboardSlashAndQuestion, shift: true)
        
        bind(.copyLastSpoken, key: .keyboardC, shift: true)
        bind(.readTextAttributes, key: .keyboardF)
        bind(.readSelection, key: .keyboardSpace, shift: true)
        
        // Double press logic needs custom handler still or we define commands for "Read Line" and "Spell Line" separately?
        // Dynamic Key Resolution
        var lineKey = InputKeyCode.keyboardL
        if let mapping = Preferences.shared.keyMapping[VoshCommand.readLine.rawValue],
           let k = InputKeyCode(rawValue: Int64(mapping.keyCode)) {
            lineKey = k
        }
        Input.shared.bindKey(key: lineKey) { [weak self] in await self?.handleDoublePress(key: lineKey, single: { await self?.perform(.readLine) }, double: { await self?.perform(.spellLine) }) }

        var wordKey = InputKeyCode.keyboardK
        if let mapping = Preferences.shared.keyMapping[VoshCommand.readWord.rawValue],
           let k = InputKeyCode(rawValue: Int64(mapping.keyCode)) {
            wordKey = k
        }
        Input.shared.bindKey(key: wordKey) { [weak self] in await self?.handleDoublePress(key: wordKey, single: { await self?.perform(.readWord) }, double: { await self?.perform(.spellWord) }) }

        var charKey = InputKeyCode.keyboardSemiColonAndColon
        if let mapping = Preferences.shared.keyMapping[VoshCommand.readCharacter.rawValue],
           let k = InputKeyCode(rawValue: Int64(mapping.keyCode)) {
            charKey = k
        }
        Input.shared.bindKey(key: charKey) { [weak self] in await self?.handleDoublePress(key: charKey, single: { await self?.perform(.readCharacter) }, double: { await self?.perform(.readPhonetic) }) }
        
        // System
        bind(.menuBar, key: .keyboardCommaAndLeftAngle)
        bind(.windowMenu, key: .keyboardM)
        bind(.dock, key: .keyboardD, shift: true)
        bind(.windowTitle, key: .keyboardW)
        bind(.listWindows, key: .keyboardW, shift: true)
        bind(.applicationName, key: .keyboardA)
        bind(.listApplications, key: .keyboardA, shift: true)
        
        // Web
        bind(.toggleBrowseMode, key: .keyboardSpace)
        
        // Review Cursor (Object Navigation)
        // Laptop Layout (Caps + Shift + Arrows)
        bind(.moveReviewNext, key: .keyboardRightArrow, shift: true)
        bind(.moveReviewPrev, key: .keyboardLeftArrow, shift: true)
        bind(.moveReviewParent, key: .keyboardUpArrow, shift: true)
        bind(.moveReviewChild, key: .keyboardDownArrow, shift: true)
        
        // Mouse Routing
        bind(.moveMouseToReviewFocus, key: .keyboardM, shift: true)
        bind(.moveReviewFocusToMouse, key: .keyboardM, ctrl: true)

        // Numpad Layout (Caps + Numpad) - Desktop style usually without Caps if Numpad Commander is off? 
        // But for global "Object Nav" we bind with Caps for safety if Numpad Commander is off?
        // Let's bind with Caps for now.
        bind(.moveReviewNext, key: .keypad6AndRightArrow)
        bind(.moveReviewPrev, key: .keypad4AndLeftArrow)
        bind(.moveReviewParent, key: .keypad8AndUpArrow)
        bind(.moveReviewChild, key: .keypad2AndDownArrow)
        bind(.moveMouseToReviewFocus, key: .keypadDivide)
        bind(.moveReviewFocusToMouse, key: .keypadMultiply)
        
        // Sync toggles
        bind(.toggleReviewFollowsFocus, key: .keyboard6AndCaret, shift: true) // ^
        bind(.toggleFocusFollowsReview, key: .keyboardSpace, shift: true) // (?)
        // Browse Keys (BrowseMode=true)
        bindBrowse(.find, key: .keyboardF)
        bindBrowse(.findNext, key: .keyboardF, shift: true)
        bindBrowse(.listLinks, key: .keyboardL, shift: true)
        bindBrowse(.listHeadings, key: .keyboardH, shift: true)
        
        bindBrowse(.browseNextHeading, key: .keyboardH)
        bindBrowse(.browsePreviousHeading, key: .keyboardH, shift: true)
        bindBrowse(.browseNextLink, key: .keyboardK)
        bindBrowse(.browsePreviousLink, key: .keyboardK, shift: true)
        bindBrowse(.browseNextEditField, key: .keyboardE)
        bindBrowse(.browsePreviousEditField, key: .keyboardE, shift: true)
        bindBrowse(.browseNextQuote, key: .keyboardQ)
        bindBrowse(.browsePreviousQuote, key: .keyboardQ, shift: true)
        // ... (Others)
        
        // Tools
        bind(.toggleSpeechViewer, key: .keyboardV, shift: true, cmd: true)
        bind(.toggleInputHelpMode, key: .keyboard1AndExclamation)
        
        // Numpad Commander
        setupNumpadCommander()
        
        // Tab
         if Preferences.shared.autoInteractOnTab {
             Input.shared.bindKey(browseMode: false, key: .keyboardTab) { [weak self] in await self?.handleTab(backwards: false) }
             Input.shared.bindKey(browseMode: false, shiftModifier: true, key: .keyboardTab) { [weak self] in await self?.handleTab(backwards: true) }
         }
    }
    
    /// Helper to bind a command to a specific key combination.
    private func bind(_ command: VoshCommand, key: InputKeyCode, shift: Bool = false, ctrl: Bool = false, opt: Bool = false, cmd: Bool = false) {
        var finalKey = key
        var finalShift = shift
        var finalCtrl = ctrl
        var finalOpt = opt
        var finalCmd = cmd
        
        // Check for User Override in Preferences
        if let shortcut = Preferences.shared.keyMapping[command.rawValue] {
            if let k = InputKeyCode(rawValue: Int64(shortcut.keyCode)) {
                finalKey = k
                let flags = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers))
                finalShift = flags.contains(.shift)
                finalCtrl = flags.contains(.control)
                finalOpt = flags.contains(.option)
                finalCmd = flags.contains(.command)
            }
        }
        
        let desc = getCommandDescription(command)
        // System wide binding
        Input.shared.bindKey(browseMode: false, controlModifier: finalCtrl, optionModifier: finalOpt, commandModifier: finalCmd, shiftModifier: finalShift, key: finalKey, description: desc) { [weak self] in
            await self?.perform(command)
        }
        // Also bind for Browse Mode if compatible?
        // Usually Vosh modifier keys override browse mode typing, so yes.
        Input.shared.bindKey(browseMode: true, controlModifier: finalCtrl, optionModifier: finalOpt, commandModifier: finalCmd, shiftModifier: finalShift, key: finalKey, description: desc) { [weak self] in
            await self?.perform(command)
        }
    }
    
    /// Generates a human-readable description for a command (used for Input Help mode).
    private func getCommandDescription(_ command: VoshCommand) -> String {
        // Map enum to readable string
        // Simple case name or explicit map
        switch command {
        case .toggleInputHelpMode: return "Toggle Input Help Mode"
        case .toggleSpeechViewer: return "Toggle Speech Viewer"
        default: return "\(command)".replacingOccurrences(of: "(?<=[a-z])(?=[A-Z])", with: " ", options: .regularExpression).capitalized
        }
    }
    
    /// Helper to bind a command specifically for Browse Mode (Web/Document).
    private func bindBrowse(_ command: VoshCommand, key: InputKeyCode, shift: Bool = false) {
        let desc = getCommandDescription(command)
        Input.shared.bindKey(browseMode: true, shiftModifier: shift, key: key, description: desc) { [weak self] in
            await self?.perform(command)
        }
    }
    
    /// Sets up Numpad Commander mappings.
    private func setupNumpadCommander() {
        Input.shared.setNumpadCommanderEnabled(Preferences.shared.numpadCommanderEnabled)
        Input.shared.onNumpadCommand = { [weak self] keyCode in
            guard let self = self else { return }
            switch keyCode {
            case .keypad1AndEnd: await self.perform(.windowMenu) // "1 = window menu bar"
            case .keypad2AndDownArrow: await self.perform(.rotorDown) // "2 = cursor down"
            case .keypad3AndPageDown: await self.perform(.contextMenu) // "3 = right click"
            case .keypad4AndLeftArrow: await self.perform(.previousItem) // "4 = cursor left"
            case .keypad5: await self.perform(.activate) // "5 = activate"
            case .keypad6AndRightArrow: await self.perform(.nextItem) // "6 = cursor right"
            case .keypad7AndHome: await self.perform(.parent) // "7 = out of current item"
            case .keypad8AndUpArrow: await self.perform(.rotorUp) // "8 = cursor up"
            case .keypad9AndPageUp: await self.perform(.firstChild) // "9 = enter item"
            case .keypadEquals: await self.perform(.menuBar) // "= = Mac menu bar"
            case .keypadDecimalAndDelete: await self.perform(.dock) // ". = dock"
            case .keypadDivide: await self.perform(.settings) // "/ = VOSH settings"
            default: break
            }
        }
    }
    
    // MARK: - Visual Highlights
    
    /// Window for highlighting the System Focus.
    private var systemFocusRing: FocusRingWindow?
    /// Window for highlighting the Review Cursor Focus.
    private var reviewFocusRing: FocusRingWindow?
    /// Window for the Speech Viewer.
    private var speechViewer: SpeechViewerWindow?
    
    /// Initializes visual feedback windows and hooks into Access events.
    private func setupVisuals() {
        // Initialize Windows
        systemFocusRing = FocusRingWindow(color: .systemBlue)
        reviewFocusRing = FocusRingWindow(color: .systemOrange)
        speechViewer = SpeechViewerWindow()
        
        systemFocusRing?.orderFront(nil)
        reviewFocusRing?.orderFront(nil)
        
        // Output Hook
        Task { @AccessActor [weak self] in
            guard let self = self else { return }
            accessibility.onCustomFocusChange = { [weak self] focus in
                await self?.updateFocusRing(window: self?.systemFocusRing, focus: focus)
            }
            
            accessibility.onCustomReviewChange = { [weak self] focus in
                await self?.updateFocusRing(window: self?.reviewFocusRing, focus: focus)
            }
        }
        
        Output.shared.onSpeech = { [weak self] text in
             self?.speechViewer?.append(text: text)
        }
    }
    
    /// Updates the position and size of a focus ring window.
    private func updateFocusRing(window: FocusRingWindow?, focus: AccessFocus) async {
        guard let window = window else { return }
        // Get Frame
        do {
            if let frameValue = try await focus.entity.element.getAttribute(.position) as? CGPoint,
               let sizeValue = try await focus.entity.element.getAttribute(.size) as? CGSize {
                let rect = CGRect(origin: frameValue, size: sizeValue)
                // Invert Y? macOS accessibility coords vs Window coords?
                // CGWindowListCreateImage uses Top-Left origin.
                // NSWindow uses Bottom-Left.
                // Accessibility API (AX) usually Bottom-Left/Screen coords?
                // Actually AX is Top-Left usually (CoreGraphics).
                // But NSWindow frame is Bottom-Left.
                // We need to flip Y.
                
                if let screen = NSScreen.main {
                    let screenHeight = screen.frame.height
                    let newY = screenHeight - rect.origin.y - rect.height
                    let flippedRect = CGRect(x: rect.origin.x, y: newY, width: rect.width, height: rect.height)
                    
                    await MainActor.run {
                        window.update(rect: flippedRect)
                    }
                }
            } else {
                 // Try getting AXFrame directly? usually implicit in position/size.
            }
        } catch {}
    }

    // MARK: - Lifecycle & Mode
    
    /// Announces the greeting message on startup.
    public func announceGreeting() async {
        setupVisuals() // Initialize visuals on startup
        Output.shared.announce(Preferences.shared.greetingMessage)
    }

    // ... (Keep existing helpers like openVoshMenu, listWindows etc. called by perform)

    /// Defines the current operational mode of the Agent interface.
    private enum AgentMode {
        /// Standard interaction mode.
        case normal
        /// Active popup menu (e.g. Window list, Vosh menu).
        case menu(title: String, items: [String], selection: Int, handler: (Int) async -> Void)
    }
    
    /// The current interaction mode state.
    private var mode: AgentMode = .normal {
        didSet {
             // Side effect: update Input browse mode?
             // If menu is open, we need browse mode to capture arrows without CapsLock.
             if case .menu = mode {
                 Input.shared.browseModeEnabled = true
             } else {
                 // Restore browse mode? Or just disable?
                 // We don't track previous browse mode state here easily.
                 // Assuming we default to false or whatever logic implies.
                 // For now, let's assume false (Focus mode) unless explicitly toggled by user separately.
                 // This is a simplification.
                 Input.shared.browseModeEnabled = false 
             }
        }
    }
    
    // Search State
    private var lastSearchText: String = ""

    /// Vosh Selector (Rotor).
    private let selector = VoshSelector()
    
    /// Initializes the Vosh Agent.
    ///
    /// This process:
    /// 1. Initializes the `Access` system (bailing if permissions fail).
    /// 2. Configures default settings and forms mode handlers.
    /// 3. Sets up bindings, visuals, and services.
    init?() async {
        guard let access = await Access() else {
            return nil
        }
        await access.setTimeout(seconds: 0.5)
        self.accessibility = access
        
        // Forms Mode Callback
        
        await accessibility.setFormsModeRequest { enterFormsMode in
            Task { @MainActor in
                // Respect global preference
                if !Preferences.shared.enableBrowseMode {
                    if Input.shared.browseModeEnabled { Input.shared.browseModeEnabled = false }
                    return
                }
                
                let targetBrowseMode = !enterFormsMode
                if Input.shared.browseModeEnabled != targetBrowseMode {
                    Input.shared.browseModeEnabled = targetBrowseMode
                    Output.shared.announce(targetBrowseMode ? "Browse Mode" : "Forms Mode")
                }
            }
        }
        
        await MainActor.run {
             // accessibility.isMouseTrackingEnabled = Preferences.shared.mouseTracking
        }
        await accessibility.setMouseTracking(Preferences.shared.mouseTracking)
        
        await accessibility.setCustomFocusHandler { focus in
            return await AppModuleManager.shared.activeModule?.onFocus(focus) ?? false
        }
        
        await syncPreferences()
        setupCommands()
        setupBindings()
        setupObservers()
        setupGestures()
        
        // Start Services
        MultitouchManager.shared.start()
        BrailleService.shared.output("Vosh Ready")
    }
    
    
    /// Sets up system-wide observers (e.g., app activation).
    private func setupObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            Task { @MainActor in
                AppModuleManager.shared.applicationDidActivate(app)
            }
        }
    }
    

    
    /// Synchronizes preferences from `Preferences` store to `Output`, `Input`, and `Access` components.
    private func syncPreferences() async {
        let prefs = Preferences.shared
        
        // Output
        Output.shared.verbosityLevel = prefs.verbosityLevel.rawValue
        Output.shared.verbosityOrder = prefs.verbosityOrder
        Output.shared.punctuationMode = prefs.punctuationMode.rawValue
        Output.shared.numberStyle = prefs.numberStyle.rawValue
        Output.shared.capsPitchChange = prefs.capPitchChange
        Output.shared.speakCap = prefs.speakCap
        Output.shared.indentationFeedback = prefs.indentationFeedback.rawValue
        Output.shared.repeatedSpacesFeedback = prefs.repeatedSpacesFeedback.rawValue
        Output.shared.textAttributesFeedback = prefs.textAttributesFeedback.rawValue
        Output.shared.misspellingFeedback = prefs.misspellingFeedback.rawValue
        Output.shared.pronunciations = prefs.pronunciations
        
        // Input
        Input.shared.typingEcho = prefs.typingEcho.rawValue
        Input.shared.announceShift = prefs.announceShift
        Input.shared.announceCommand = prefs.announceCommand
        Input.shared.announceControl = prefs.announceControl
        Input.shared.announceOption = prefs.announceOption
        Input.shared.announceCapsLock = prefs.announceCapsLock
        Input.shared.announceTab = prefs.announceTab
        Input.shared.deletionFeedback = prefs.deletionFeedback.rawValue
        
        // Capture MainActor values
        let autoSpeakDialogs = prefs.autoSpeakDialogs
        let progressFeedback = prefs.progressFeedback.rawValue
        let speakBackgroundProgress = prefs.speakBackgroundProgress
        let tableRowChangeFeedback = prefs.tableRowChangeFeedback.rawValue
        let speakTextUnderMouse = prefs.speakTextUnderMouse
        let speakUnderMouseDelay = prefs.speakUnderMouseDelay
        let mouseFollowsCursor = prefs.mouseFollowsCursor
        let cursorFollowsMouse = prefs.cursorFollowsMouse
        let cursorInitialPosition = prefs.cursorInitialPosition
        let syncFocus = prefs.syncFocus
        let wrapAround = prefs.wrapAround
        let intelligentAutoFocus = prefs.intelligentAutoFocus
        
        let webLoadFeedback = prefs.webLoadFeedback.rawValue
        let speakWebSummary = prefs.speakWebSummary
        let autoReadWebPage = prefs.autoReadWebPage

        // Access
        Task { @AccessActor in
            accessibility.autoSpeakDialogs = autoSpeakDialogs
            accessibility.progressFeedback = progressFeedback
            accessibility.speakBackgroundProgress = speakBackgroundProgress
            accessibility.tableRowChangeFeedback = tableRowChangeFeedback
            accessibility.speakTextUnderMouse = speakTextUnderMouse
            accessibility.speakUnderMouseDelay = speakUnderMouseDelay
            accessibility.mouseFollowsCursor = mouseFollowsCursor
            accessibility.cursorFollowsMouse = cursorFollowsMouse
            accessibility.cursorInitialPosition = cursorInitialPosition
            accessibility.syncFocus = syncFocus
            accessibility.wrapAround = wrapAround
            accessibility.intelligentAutoFocus = intelligentAutoFocus
            
            // Web
            accessibility.webLoadFeedback = webLoadFeedback
            accessibility.speakWebSummary = speakWebSummary
            accessibility.autoReadWebPage = autoReadWebPage
            accessibility.webLoadFeedback = webLoadFeedback
            accessibility.speakWebSummary = speakWebSummary
            accessibility.autoReadWebPage = autoReadWebPage
        }
        
        // Enforce Browse Mode State
        if !prefs.enableBrowseMode {
            Input.shared.browseModeEnabled = false
        }
        
        // Push Audio Engine Settings
        await AudioEngine.shared.configure(
             isSpatialEnabled: prefs.spatialAudioEnabled,
             reverb: AVAudioUnitReverbPreset(rawValue: prefs.reverbPreset) ?? .smallRoom
        )
        
        // Push Braille Settings
        let table = prefs.brailleTranslationTable
        await MainActor.run {
            BrailleService.shared.translationTable = table
        }
    }
    
    // MARK: - Gesture System
    
    /// Configures Trackpad gesture recognizers and maps them to Vosh commands.
    private func setupGestures() {
        // Defaults
        var mapping = Preferences.shared.gestureMapping
        if mapping.isEmpty {
            mapping = [
                "swipeUpThreeFinger": VoshCommand.readEntireWindow.rawValue,
                "swipeDownThreeFinger": VoshCommand.readFromTop.rawValue,
                "tapTwoFinger": VoshCommand.toggleSpeech.rawValue, // Pause/Resume often 2-finger tap
                "rotateClockwise": VoshCommand.rotorNext.rawValue,
                "rotateCounterClockwise": VoshCommand.rotorPrevious.rawValue
            ]
            Preferences.shared.gestureMapping = mapping
        }
        
        Input.shared.trackpad.onGesture = { [weak self] gesture in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let key: String
                switch gesture {
                case .tapOneFinger: key = "tapOneFinger"
                case .tapTwoFinger: key = "tapTwoFinger"
                case .tapFourFinger: key = "tapFourFinger"
                case .swipeUpThreeFinger: key = "swipeUpThreeFinger"
                case .swipeDownThreeFinger: key = "swipeDownThreeFinger"
                case .rotateClockwise: key = "rotateClockwise"
                case .rotateCounterClockwise: key = "rotateCounterClockwise"
                }
                
                if let rawCmd = mapping[key], let command = VoshCommand(rawValue: rawCmd) {
                    await self.perform(command)
                }
            }
        }
    }

    
    // MARK: - Rotor Handlers
    
    // MARK: - Rotor Handlers
    
    /// Handles the "Rotor Up" action (Previous value in current Rotor setting).
    private func handleRotorUp() async {
        switch selector.currentOption {
        case .navigation:
            await accessibility.focusParent()
        case .lines:
             await accessibility.moveReviewCursor(unit: "Line", backwards: true)
        case .words:
             await accessibility.moveReviewCursor(unit: "Word", backwards: true)
        case .characters:
             await accessibility.moveReviewCursor(unit: "Character", backwards: true)
        case .headings:
             await accessibility.browsePreviousElement(role: "Heading")
        case .links:
             await accessibility.browsePreviousElement(role: "Link")
        case .buttons:
             await accessibility.browsePreviousElement(role: "Button")
        case .windows:
             await accessibility.focusPreviousWindow()
        }
    }
    
    /// Handles the "Rotor Down" action (Next value in current Rotor setting).
    private func handleRotorDown() async {
        switch selector.currentOption {
        case .navigation:
            await accessibility.focusFirstChild()
        case .lines:
             await accessibility.moveReviewCursor(unit: "Line", backwards: false)
        case .words:
             await accessibility.moveReviewCursor(unit: "Word", backwards: false)
        case .characters:
             await accessibility.moveReviewCursor(unit: "Character", backwards: false)
        case .headings:
             await accessibility.browseNextElement(role: "Heading")
        case .links:
             await accessibility.browseNextElement(role: "Link")
        case .buttons:
             await accessibility.browseNextElement(role: "Button")
        case .windows:
             await accessibility.focusNextWindow()
        }
    }
    /// Helper to bind a custom closure action specifically for Browse Mode.
    private func bindBrowse(shift: Bool = false, key: InputKeyCode, action: @escaping () async -> Void) {
        Input.shared.bindKey(browseMode: true, shiftModifier: shift, key: key) { [weak self] in
            guard let self = self else { return }
            if case .menu = self.mode { return }
            await action()
        }
    }
    
    // MARK: - Action Handlers
    
    // MARK: - Action Handlers
    
    // MARK: Menu Navigation
    
    /// Handles Up Arrow in internal menus (previous item).
    private func handleMenuUp() async {
        if case .menu(let title, let items, let selection, let handler) = mode {
            let newSelection = max(0, selection - 1)
            mode = .menu(title: title, items: items, selection: newSelection, handler: handler)
            Output.shared.announce(items[newSelection])
        } else {
            // Virtual Buffer Navigation
            await accessibility.browsePrevious()
        }
    }
    
    /// Handles Down Arrow in internal menus (next item).
    private func handleMenuDown() async {
        if case .menu(let title, let items, let selection, let handler) = mode {
            let newSelection = min(items.count - 1, selection + 1)
            mode = .menu(title: title, items: items, selection: newSelection, handler: handler)
            Output.shared.announce(items[newSelection])
        } else {
             // Virtual Buffer Navigation
             await accessibility.browseNext()
        }
    }
    
    /// Handles Enter/Space in internal menus (activate selection).
    private func handleMenuEnter() async {
        if case .menu(_, _, let selection, let handler) = mode {
            mode = .normal // Exit menu before handler? Or let handler decide?
            // Usually valid to exit.
            await handler(selection)
        }
    }
    
    /// Handles Escape key (exit menu, close dialogs, or toggle focus/browse).
    private func handleEscape() async {
        if case .menu = mode {
            mode = .normal
            Output.shared.announce("Cancelled")
        } else {
            let webActive = await accessibility.isWebActive
            if webActive && !Input.shared.browseModeEnabled && Preferences.shared.enableBrowseMode {
                 Input.shared.browseModeEnabled = true
                 Output.shared.announce("Browse Mode")
            } else {
               // Default Escape behavior
            }
        }
    }
    
    // MARK: - Command Implementations
    
    /// The currently active navigation task. Used to cancel stale requests during rapid key presses.
    private var navigationTask: Task<Void, Never>?
    
    /// Wraps navigation actions to ensure previous pending navigation tasks are cancelled.
    /// This prevents "runaway cursor" where rapid key presses queue up more speech than can be processed.
    private func performNavigation(_ action: @escaping (VoshAgent) async -> Void) {
        navigationTask?.cancel()
        navigationTask = Task {
            // Optional debounce could go here if needed
            if Task.isCancelled { return }
            await action(self)
        }
    }
    
    private var singlePressTasks = [InputKeyCode: Task<Void, Never>]()

    /// Handles logic for distinguishing single vs double key presses.
    /// - Parameters:
    ///   - key: The key being pressed.
    ///   - single: Action to perform on single press (after timeout).
    ///   - double: Action to perform immediately on double press.
    private func handleDoublePress(key: InputKeyCode, single: @escaping () async -> Void, double: @escaping () async -> Void) async {
        // Cancel any pending single action for this key
        singlePressTasks[key]?.cancel()
        singlePressTasks[key] = nil
        
        let now = DispatchTime.now().uptimeNanoseconds
        
        if let last = lastPressTimes[key], now - last < doublePressThreshold {
            // Double Press Detected
            lastPressTimes[key] = 0 // Reset
            await double()
        } else {
            // First Press - Schedule Single Action with delay
            lastPressTimes[key] = now
            
            let task = Task {
                do {
                    try await Task.sleep(nanoseconds: doublePressThreshold)
                    // If not cancelled, run single
                    if !Task.isCancelled {
                        await single()
                    }
                } catch is CancellationError {
                    // Cancelled by double press
                } catch {}
             
                // Cleanup
                self.singlePressTasks[key] = nil
                
                // Reset timestamp validation?
                if self.lastPressTimes[key] == now {
                    self.lastPressTimes[key] = 0
                }
            }
            singlePressTasks[key] = task
        }
    }
    
    // MARK: - Reading helpers
    

    
    private func readSelection() async {
        if let sel = await accessibility.getSelectedText() {
            Output.shared.announce("Selection: \(sel)")
        } else {
            Output.shared.announce("No selection")
        }
    }
    

    /// Opens the Vosh main menu.
    private func openVoshMenu() async {
        let items = ["Preferences", "Check for Updates", "Quit Vosh"]
        mode = .menu(title: "Vosh Menu", items: items, selection: 0) { index in
            if index == 2 { await self.quitVosh() }
            else { Output.shared.announce("Not implemented") }
        }
        Output.shared.announce("Vosh Menu. \(items[0])")
    }
    
    private var lastQuitAttempt: TimeInterval = 0
    
    /// Quits Vosh (with confirmation if configured).
    private func quitVosh() async {
        if Preferences.shared.confirmOnExit {
            let now = Date().timeIntervalSince1970
            if now - lastQuitAttempt > 3.0 {
                lastQuitAttempt = now
                Output.shared.announce("Press again to quit")
                return
            }
        }
        
        // Output goodbye message
        Output.shared.announce(Preferences.shared.goodbyeMessage)
        try? await Task.sleep(nanoseconds: 700_000_000)
        NSApplication.shared.terminate(nil)
    }
    
    /// Toggles speech output on/off.
    private func toggleSpeech() async {
        Output.shared.isMuted.toggle()
        if !Output.shared.isMuted {
            Output.shared.announce("Speech On")
        }
    }
    
    /// Toggles the screen curtain (privacy blackout).
    private func toggleScreenCurtain() async {
        Output.shared.isScreenCurtainEnabled.toggle()
        Output.shared.announce(Output.shared.isScreenCurtainEnabled ? "Screen Curtain On" : "Screen Curtain Off")
    }
    
    private func openNotificationCenter() async {
         Output.shared.announce("Notification Center")
    }
    
    private func openControlCenter() async {
         Output.shared.announce("Control Center")
    }
    
    // MARK: System Access
    
    /// Moves focus to the System Menu Bar.
    private func accessMenuBar() async {
        Output.shared.announce("Menu Bar")
        // Control + F2
        await performSystemKey(keyCode: 120, modifiers: .maskControl) // F2 = 120 (0x78)
    }
    
    private func accessWindowMenu() async {
        Output.shared.announce("Window Menu")
        // Not easily accessible via standard keyboard shortcut universally.
    }
    
    private func accessContextMenu() async {
        Output.shared.announce("Context Menu (Not implemented)")
        // logic pending: simulate right click
    }
    
    private func accessDock() async {
        Output.shared.announce("Dock")
        // Control + F3
        await performSystemKey(keyCode: 99, modifiers: .maskControl) // F3 = 99 (0x63)
    }
    
    private func accessNotificationCenter() async {
         Output.shared.announce("Notification Center")
         // AppleScript removed.
         // Standard shortcut differs by keyboard (Fn+N, etc).
         // Future: Access via SystemUIServer or specific Accessibility element logic.
         Output.shared.announce("Not supported without AppleScript yet")
    }
    
    private func accessControlCenter() async {
         Output.shared.announce("Control Center")
    }
    
    private func toggleInputHelpMode() async {
        Input.shared.inputHelpModeEnabled.toggle()
        Output.shared.announce(Input.shared.inputHelpModeEnabled ? "Input Help On" : "Input Help Off")
    }
    
    private func passNextKey() async {
        Input.shared.passNextKeyToSystem()
    }
    
    // announceWindowTitle implemented below around line 1123

    
    
    /// Helper to synthesize a system key press.
    private func performSystemKey(keyCode: CGKeyCode, modifiers: CGEventFlags) async {
         await MainActor.run {
             let source = CGEventSource(stateID: .hidSystemState)
             guard let eventDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) else { return }
             eventDown.flags = modifiers
             eventDown.post(tap: .cghidEventTap)
             
             guard let eventUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
             eventUp.flags = modifiers
             eventUp.post(tap: .cghidEventTap)
         }
    }

    /// Handles Tab key for navigation, potentially delegating to Access smart interaction.
    private func handleTab(backwards: Bool) async {
         Input.shared.passNextKeyToSystem()
         
         let source = CGEventSource(stateID: .hidSystemState)
         if let event = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: true) { // Tab = 0x30 (48)
             if backwards { event.flags.insert(.maskShift) }
             event.post(tap: .cghidEventTap)
         }
         
         if let eventUp = CGEvent(keyboardEventSource: source, virtualKey: 0x30, keyDown: false) {
             if backwards { eventUp.flags.insert(.maskShift) }
             eventUp.post(tap: .cghidEventTap)
         }
         
         try? await Task.sleep(nanoseconds: 150_000_000) // 150ms wait for focus change
         await accessibility.attemptSmartInteraction() // Will check focus and interact if simple
    }
    
    
    /// Moves mouse to current focus and clicks.
    private func moveMouseAndClick() async {
        await accessibility.moveMouseToFocus(click: true)
    }
    
    /// Moves mouse to current focus without clicking.
    private func moveMouseToFocus() async {
        await accessibility.moveMouseToFocus(click: false)
    }
    
    // MARK: - Reading
    
    /// Reads the entire content of the current window or web area.
    func readEntireWindow() async {
        if Input.shared.browseModeEnabled {
            Output.shared.announce("Reading Web Content...")
            await accessibility.readAllWeb()
        } else {
            Output.shared.announce("Reading Window...")
            await accessibility.readAllRecursively()
        }
    }
    
    /// Reads from the current cursor position to the end.
    func readFromCursor() async {
         if Input.shared.browseModeEnabled {
              await accessibility.readAllWeb() // Live walker handles "from cursor" implicitly by current state
         } else {
              // Standard implementation for non-web?
              // For now alias to read entire window or implement specific logic later.
              // Just announce logic stub.
              Output.shared.announce("Read from cursor not supported in standard mode yet.")
         }
    }
    
    private func readClipboard() async {
        guard let str = NSPasteboard.general.string(forType: .string), !str.isEmpty else {
            Output.shared.announce("Clipboard empty")
            return
        }
        
        let limit = 500
        if str.count > limit {
            let snippet = str.prefix(limit)
            let remaining = str.count - limit
            Output.shared.announce("Clipboard: \(snippet)... and \(remaining) more characters.")
        } else {
            Output.shared.announce("Clipboard: \(str)")
        }
    }
    
    private func readTimeDate() async {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        let str = formatter.string(from: date)
        Output.shared.announce(str)
    }
    /// Reads the current line of text under focus/review.
    private func readCurrentLine() async {
        await accessibility.readCurrentLine(spell: false)
    }
    
    /// Spells out the current line of text.
    private func spellCurrentLine() async {
        await accessibility.readCurrentLine(spell: true)
    }
    
    private func readCurrentSentence() async {
        Output.shared.announce("Current Sentence")
    }
    
    /// Reads the current word under the cursor.
    private func readCurrentWord() async {
        await accessibility.readCurrentWord(spell: false)
    }
    
    /// Spells out the current word.
    private func spellCurrentWord() async {
        await accessibility.readCurrentWord(spell: true)
    }
    
    /// Reads the current character.
    private func readCurrentCharacter() async {
        await self.accessibility.readCurrentCharacter(phonetic: false)
    }
    
    /// Reads the current character phonetically (e.g. "Alpha").
    private func readCurrentCharacterPhonetically() async {
        await self.accessibility.readCurrentCharacter(phonetic: true)
    }
    
    // MARK: Web / Browse
    
    /// Toggles Browse Mode (virtual cursor for web).
    func toggleBrowseMode() async {
        if !Preferences.shared.enableBrowseMode {
             Output.shared.announce("Browse Mode is disabled in settings")
             Input.shared.browseModeEnabled = false
             return
        }
        Input.shared.browseModeEnabled.toggle()
        Output.shared.announce(Input.shared.browseModeEnabled ? "Browse Mode On" : "Browse Mode Off")
    }
    
    /// Opens the Find dialog for the current document.
    func openFindDialog() async {
        let text = InputWindow.requestInput(title: "Find", prompt: "Enter text to find:")
        guard let searchText = text, !searchText.isEmpty else { return }
        
        lastSearchText = searchText
        Output.shared.announce("Searching for \(searchText)")
        await accessibility.findBrowseElement(text: searchText)
    }

    /// Finds the next occurrence of the previous search term.
    func findNext() async {
        guard !lastSearchText.isEmpty else {
            Output.shared.announce("No previous search")
            return
        }
        await accessibility.findBrowseElement(text: lastSearchText)
    }

    // MARK: - Missing Command Implementations
    
    // accessContextMenu, accessDock implemented above.
    // announceWindowTitle implemented below.
    
    func announceWindowTitle() async {
        if let title = await accessibility.getFocusedWindowTitle() {
            Output.shared.announce(title)
        } else {
            Output.shared.announce("No Window")
        }
    }
    
    // Searchable List State
    // private var currentListWindow: AnyObject? // Keep window alive
    
    func listLinks() async {
        guard Input.shared.browseModeEnabled else {
            Output.shared.announce("Only available in Browse Mode")
            return
        }
        
        Output.shared.announce("Scanning Links...")
        let links = await accessibility.findAllBrowseElements(role: "Link")
        
        if links.isEmpty {
            Output.shared.announce("No links found")
            return
        }
        
        await MainActor.run {
            let window = SearchableListWindow(title: "Links", items: links.map { $0.title }) { index in
                let selected = links[index].element
                Task { await self.accessibility.focusBrowseElement(selected) }
            }
            window.show()
        }
    }

    func listHeadings() async {
        guard Input.shared.browseModeEnabled else {
            Output.shared.announce("Only available in Browse Mode")
            return
        }
        
        Output.shared.announce("Scanning Headings...")
        let headings = await accessibility.findAllBrowseElements(role: "Heading")
        
        if headings.isEmpty {
            Output.shared.announce("No headings found")
            return
        }
        
        await MainActor.run {
            let window = SearchableListWindow(title: "Headings", items: headings.map { $0.title }) { index in
                let selected = headings[index].element
                Task { await self.accessibility.focusBrowseElement(selected) }
            }
            window.show()
        }
    }
    
    private func findNextElement(role: String, backwards: Bool = false) async {
        Output.shared.announce("Next \(role)")
    }
    
    // MARK: Vision / AI
    
    /// Captures the screen and uses AI to describe the image.
    func describeImage() async {
        Output.shared.announce("Describing...")
        guard let image = SnapshotManager.captureScreen() else {
             Output.shared.announce("Screen Capture Failed")
             return
        }
        
        let description = try? await VisionService.shared.describeImage(image)
        Output.shared.announce(description ?? "No description")
    }
    
    /// Performs OCR on the current screen content.
    func ocrScreen() async {
        Output.shared.announce("Scanning...")
        guard let image = SnapshotManager.captureScreen() else {
            Output.shared.announce("Failed to capture screen")
            return
        }
        
        do {
            let text = try await VisionService.shared.recognizeText(in: image)
            if text.isEmpty {
                Output.shared.announce("No text found")
            } else {
                Output.shared.announce("Text found")
                // Present in a window or speak all? For now, speak summary or copy to clipboard?
                // Let's just output it.
                Output.shared.announce(text)
            }
        } catch {
            Output.shared.announce("Error: \(error.localizedDescription)")
        }
    }
    
    private func toggleScriptConsole() async {
        // await Output.shared.announce("Script Console")
        let command = InputWindow.requestInput(title: "Script Console", prompt: "Enter command:")
        guard let cmd = command, !cmd.isEmpty else { return }
        let result = await ScriptManager.shared.execute(command: cmd)
        Output.shared.announce(result)
    }
    
    /// Lists all open windows in a menu for quick navigation.
    func listWindows() async {
        Output.shared.announce("Windows")
        let windows = await accessibility.getWindows()
        guard !windows.isEmpty else {
            Output.shared.announce("No windows found")
            return
        }
        
        // Show popup menu
        let items = windows.map { $0.title }
        mode = .menu(title: "Window List", items: items, selection: 0) { index in
            let window = windows[index].element
            // Focus window
            Task {
                await self.accessibility.raiseWindow(window)
            }
        }
        // Enter Browse Mode for menu navigation
        // Enter Browse Mode for menu navigation
        Input.shared.browseModeEnabled = true
        // Announce first item
        Output.shared.announce(items[0])
    }
    
    /// Announces the name of the currently active application.
    func announceApplicationName() async {
        let name = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        Output.shared.announce(name)
    }
    
    /// Lists all running applications in a menu.
    func listApplications() async {
        Output.shared.announce("Applications")
        let apps = accessibility.getApplications()
        guard !apps.isEmpty else { return }
        
        let items = apps.map { $0.name }
        mode = .menu(title: "Application List", items: items, selection: 0) { [weak self] index in
            guard let self = self else { return }
            let appParams = apps[index]
            self.accessibility.focusApplication(processIdentifier: appParams.processIdentifier)
        }
        Input.shared.browseModeEnabled = true
         Output.shared.announce(items[0])
    }
    
    // MARK: - Braille
    
    /// Toggles Braille input mode.
    private func toggleBrailleInput() async {
        Input.shared.brailleInputEnabled.toggle()
        let state = Input.shared.brailleInputEnabled ? "On" : "Off"
        Output.shared.announce("Braille Input \(state)")
    }
    
    // MARK: - AI Assistant
    
    /// Triggers the "Ask Vosh" AI assistant.
    func askVosh() async {
        // 1. Capture the screen IMMEDIATELY (before showing any UI)
        Output.shared.announce("Capturing...")
        guard let image = SnapshotManager.captureScreen() else {
            Output.shared.announce("Screen Capture Failed")
            return
        }
        
        // 2. Request User Query (Now safe due to Input fix)
        // We use a slight delay or ensure runModal doesn't block the audio announcement completely
        await MainActor.run {
            guard let query = InputWindow.requestInput(title: "Ask Vosh", prompt: "What would you like to know about this screen?") else {
                Output.shared.announce("Cancelled")
                return
            }
            
            guard !query.isEmpty else { return }
            
            // 3. Process with Vision/AI (Async)
            Task {
                Output.shared.announce("Thinking...")
                do {
                    // Call the VisionService (which mocks the LLM/AI part for now)
                    let response = try await VisionService.shared.ask(query: query, image: image)
                    Output.shared.announce(response)
                } catch {
                    Output.shared.announce("AI Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
