//
//  SettingsWindow.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import Output
import AVFoundation

/// The main preferences window controller for Vosh.
///
/// `SettingsWindow` constructs and manages the tabbed interface for configuring all user settings,
/// mapping UI controls (checkboxes, sliders, popups) directly to the persistent properties in `Preferences`.
@MainActor
final class SettingsWindow: NSWindowController {
    /// Shared singleton instance of the settings window.
    static let shared = SettingsWindow()
    
    private let preferences = Preferences.shared
    
    /// Private initializer that constructs the window and all tab layouts programmatically.
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 450, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vosh Settings"
        super.init(window: window)
        
        let contentView = NSView(frame: window.contentView!.bounds)
        window.contentView = contentView
        
        // Tab View
        let tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]
        
        // General Tab
        let generalItem = NSTabViewItem(identifier: "General")
        generalItem.label = "General"
        let generalView = NSView(frame: tabView.contentRect)
        
        let loginCheck = NSButton(checkboxWithTitle: "Start Vosh at Login", target: self, action: #selector(loginChanged(_:)))
        loginCheck.state = preferences.startAtLogin ? .on : .off
        loginCheck.frame = NSRect(x: 20, y: 220, width: 250, height: 24)
        generalView.addSubview(loginCheck)
        
        // General - Keyboard Layout
        addLabel(to: generalView, text: "Keyboard Layout:", y: 180, width: 120)
        let kbPopup = NSPopUpButton(frame: NSRect(x: 20, y: 155, width: 200, height: 24), pullsDown: false)
        kbPopup.addItems(withTitles: ["Laptop (No numpad)", "Desktop (Numpad)"])
        if preferences.keyboardLayout == "Desktop (Numpad)" { kbPopup.selectItem(at: 1) }
        kbPopup.target = self
        kbPopup.action = #selector(kbLayoutChanged(_:))
        generalView.addSubview(kbPopup)
        
        // Intelligent Auto Focus
        let autoFocusCheck = NSButton(checkboxWithTitle: "Intelligent Auto Focus", target: self, action: #selector(autoFocusChanged(_:)))
        autoFocusCheck.state = preferences.intelligentAutoFocus ? .on : .off
        autoFocusCheck.frame = NSRect(x: 20, y: 190, width: 250, height: 24)
        generalView.addSubview(autoFocusCheck)
        
        // General - Sleep Mode
        let sleepCheck = NSButton(checkboxWithTitle: "Enable Sleep Mode", target: self, action: #selector(sleepChanged(_:)))
        sleepCheck.state = preferences.sleepMode ? .on : .off
        sleepCheck.frame = NSRect(x: 20, y: 120, width: 200, height: 24)
        generalView.addSubview(sleepCheck)
        
        // General - Greeting & Goodbye
        addLabel(to: generalView, text: "Greeting:", y: 90, width: 60)
        let greetField = NSTextField(frame: NSRect(x: 80, y: 88, width: 250, height: 22))
        greetField.stringValue = preferences.greetingMessage
        greetField.target = self
        greetField.action = #selector(greetingChanged(_:))
        generalView.addSubview(greetField)
        
        addLabel(to: generalView, text: "Goodbye:", y: 60, width: 60)
        let byeField = NSTextField(frame: NSRect(x: 80, y: 58, width: 250, height: 22))
        byeField.stringValue = preferences.goodbyeMessage
        byeField.target = self
        byeField.action = #selector(goodbyeChanged(_:))
        generalView.addSubview(byeField)
        
        let confirmCheck = NSButton(checkboxWithTitle: "Confirm on Exit", target: self, action: #selector(confirmExitChanged(_:)))
        confirmCheck.state = preferences.confirmOnExit ? .on : .off
        confirmCheck.frame = NSRect(x: 20, y: 30, width: 200, height: 24)
        generalView.addSubview(confirmCheck)
        
        generalItem.view = generalView
        tabView.addTabViewItem(generalItem)
        
        // Input Tab (Advanced)
        let inputItem = NSTabViewItem(identifier: "Input")
        inputItem.label = "Input"
        let inputView = NSView(frame: tabView.contentRect)
        
        // Numpad Commander
        let numpadCheck = NSButton(checkboxWithTitle: "Numpad Commander", target: self, action: #selector(numpadCmdChanged(_:)))
        numpadCheck.state = preferences.numpadCommanderEnabled ? .on : .off
        numpadCheck.frame = NSRect(x: 20, y: 450, width: 250, height: 24)
        inputView.addSubview(numpadCheck)
        
        // Modifiers
        let modBox = NSBox(frame: NSRect(x: 20, y: 250, width: 300, height: 180))
        modBox.title = "Vosh Modifier Keys"
        inputView.addSubview(modBox)
        
        func addVoshMod(_ title: String, y: Double, action: Selector, selected: Bool) {
            let check = NSButton(checkboxWithTitle: title, target: self, action: action)
            check.state = selected ? .on : .off
            check.frame = NSRect(x: 20, y: y, width: 200, height: 24)
            modBox.contentView?.addSubview(check)
        }
        
        addVoshMod("Caps Lock", y: 130, action: #selector(voshCapChanged(_:)), selected: preferences.voshModifiers.contains(.capsLock))
        addVoshMod("Numpad 0 / Insert", y: 100, action: #selector(voshNumChanged(_:)), selected: preferences.voshModifiers.contains(.numpad0))
        addVoshMod("Control + Option", y: 70, action: #selector(voshCtrlOptChanged(_:)), selected: preferences.voshModifiers.contains(.ctrlOption))
        
        inputItem.view = inputView
        tabView.addTabViewItem(inputItem)
        
        // ... Speech Tab ... (Already done) ...
        
        // Speech Tab
        let speechItem = NSTabViewItem(identifier: "Speech")
        speechItem.label = "Speech"
        let speechView = NSView(frame: tabView.contentRect)
        
        // Verbosity
        addLabel(to: speechView, text: "Verbosity:", y: 450, width: 70)
        let verbPopup = NSPopUpButton(frame: NSRect(x: 90, y: 448, width: 100, height: 24), pullsDown: false)
        verbPopup.addItems(withTitles: ["Low", "Medium", "High"])
        verbPopup.selectItem(at: preferences.verbosityLevel.rawValue)
        verbPopup.target = self
        verbPopup.action = #selector(verbosityChanged(_:))
        speechView.addSubview(verbPopup)
        
        // Punctuation
        addLabel(to: speechView, text: "Punctuation:", y: 420, width: 80)
        let puncPopup = NSPopUpButton(frame: NSRect(x: 90, y: 418, width: 100, height: 24), pullsDown: false)
        puncPopup.addItems(withTitles: ["None", "Some", "Most", "All"])
        puncPopup.selectItem(at: preferences.punctuationMode.rawValue)
        puncPopup.target = self
        puncPopup.action = #selector(punctChanged(_:))
        speechView.addSubview(puncPopup)
        
        // Voice Selection
        addLabel(to: speechView, text: "Voice:", y: 390, width: 60)
        let voicePopup = NSPopUpButton(frame: NSRect(x: 80, y: 388, width: 250, height: 24), pullsDown: false)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        voicePopup.addItems(withTitles: voices.map { "\($0.name) (\($0.language))" })
        if let currentId = preferences.selectedVoiceIdentifier, let index = voices.firstIndex(where: { $0.identifier == currentId }) {
            voicePopup.selectItem(at: index)
        }
        voicePopup.target = self
        voicePopup.action = #selector(voiceChanged(_:))
        speechView.addSubview(voicePopup)
        
        // Rate Slider
        addLabel(to: speechView, text: "Rate:", y: 360, width: 60)
        let rateSlider = NSSlider(value: Double(preferences.speechRate), minValue: 0.1, maxValue: 1.0, target: self, action: #selector(rateChanged(_:)))
        rateSlider.frame = NSRect(x: 80, y: 358, width: 200, height: 24)
        speechView.addSubview(rateSlider)
        
        // Volume Slider
        addLabel(to: speechView, text: "Volume:", y: 330, width: 60)
        let volSlider = NSSlider(value: Double(preferences.speechVolume), minValue: 0.0, maxValue: 1.0, target: self, action: #selector(volumeChanged(_:)))
        volSlider.frame = NSRect(x: 80, y: 328, width: 200, height: 24)
        speechView.addSubview(volSlider)
        
        // Pitch Slider
        addLabel(to: speechView, text: "Pitch:", y: 300, width: 60)
        let pitchSlider = NSSlider(value: Double(preferences.pitch), minValue: 0.5, maxValue: 2.0, target: self, action: #selector(pitchChanged(_:)))
        pitchSlider.frame = NSRect(x: 80, y: 298, width: 200, height: 24)
        speechView.addSubview(pitchSlider)
        
        // Cap Pitch
        addLabel(to: speechView, text: "Cap Pitch %:", y: 270, width: 80)
        let capSlider = NSSlider(value: Double(preferences.capPitchChange), minValue: 0.0, maxValue: 50.0, target: self, action: #selector(capPitchChanged(_:)))
        capSlider.frame = NSRect(x: 100, y: 268, width: 150, height: 24)
        speechView.addSubview(capSlider)
        
        let speakCapCheck = NSButton(checkboxWithTitle: "Speak 'Cap'", target: self, action: #selector(speakCapChanged(_:)))
        speakCapCheck.state = preferences.speakCap ? .on : .off
        speakCapCheck.frame = NSRect(x: 260, y: 268, width: 100, height: 24)
        speechView.addSubview(speakCapCheck)

        // Ducking Checkbox
        let duckingCheck = NSButton(checkboxWithTitle: "Audio Ducking", target: self, action: #selector(duckingChanged(_:)))
        duckingCheck.state = preferences.audioDucking ? .on : .off
        duckingCheck.frame = NSRect(x: 80, y: 240, width: 200, height: 24)
        speechView.addSubview(duckingCheck)
        
        // Spatial Checkbox
        let spatialCheck = NSButton(checkboxWithTitle: "Enable Spatial Audio", target: self, action: #selector(spatialChanged(_:)))
        spatialCheck.state = preferences.spatialAudioEnabled ? .on : .off
        spatialCheck.frame = NSRect(x: 80, y: 210, width: 200, height: 24)
        speechView.addSubview(spatialCheck)
        
        // Width Slider
        let widthLabel = NSTextField(labelWithString: "Stereo Width:")
        widthLabel.frame = NSRect(x: 80, y: 180, width: 90, height: 18)
        speechView.addSubview(widthLabel)
        
        let widthSlider = NSSlider(value: Double(preferences.stereoWidth), minValue: 0.0, maxValue: 2.0, target: self, action: #selector(widthChanged(_:)))
        widthSlider.frame = NSRect(x: 180, y: 180, width: 100, height: 24)
        speechView.addSubview(widthSlider)
        
        // Reverb Picker
        let reverbLabel = NSTextField(labelWithString: "Ambience:")
        reverbLabel.frame = NSRect(x: 80, y: 150, width: 80, height: 18)
        speechView.addSubview(reverbLabel)
        
        let reverbPicker = NSPopUpButton(frame: NSRect(x: 180, y: 148, width: 120, height: 24), pullsDown: false)
        reverbPicker.addItems(withTitles: ["Small", "Medium", "Large", "Cathedral"])
        reverbPicker.selectItem(at: preferences.reverbPreset)
        reverbPicker.target = self
        reverbPicker.action = #selector(reverbChanged(_:))
        speechView.addSubview(reverbPicker)
        
        // Number Reading
        let numLabel = NSTextField(labelWithString: "Numbers:")
        numLabel.frame = NSRect(x: 80, y: 120, width: 60, height: 18)
        speechView.addSubview(numLabel)
        let numPopup = NSPopUpButton(frame: NSRect(x: 150, y: 118, width: 100, height: 24), pullsDown: false)
        numPopup.addItems(withTitles: ["Words", "Digits"])
        numPopup.selectItem(at: preferences.numberStyle.rawValue)
        numPopup.target = self
        numPopup.action = #selector(numStyleChanged(_:))
        speechView.addSubview(numPopup)
        
        speechItem.view = speechView
        tabView.addTabViewItem(speechItem)
        
        // Typing Tab
        let typingItem = NSTabViewItem(identifier: "Typing")
        typingItem.label = "Typing"
        let typingView = NSView(frame: tabView.contentRect)
        
        // Typing Echo
        addLabel(to: typingView, text: "Typing Echo:", y: 250, width: 100)
        let echoPopup = NSPopUpButton(frame: NSRect(x: 120, y: 248, width: 150, height: 24), pullsDown: false)
        echoPopup.addItems(withTitles: ["None", "Characters", "Words", "Both"])
        echoPopup.selectItem(at: preferences.typingEcho.rawValue)
        echoPopup.target = self
        echoPopup.action = #selector(typingEchoChanged(_:))
        typingView.addSubview(echoPopup)
        
        // Deletion Feedback
        addLabel(to: typingView, text: "Deletion:", y: 220, width: 100)
        let delPopup = NSPopUpButton(frame: NSRect(x: 120, y: 218, width: 150, height: 24), pullsDown: false)
        delPopup.addItems(withTitles: ["None", "Speak", "Tone"])
        delPopup.selectItem(at: preferences.deletionFeedback.rawValue)
        delPopup.target = self
        delPopup.action = #selector(deletionFeedbackChanged(_:))
        typingView.addSubview(delPopup)
        
        // Modifiers
        let modifiersBox = NSBox(frame: NSRect(x: 20, y: 20, width: 340, height: 180))
        modifiersBox.title = "Announce Modifiers"
        typingView.addSubview(modifiersBox)
        
        func addModCheck(_ title: String, y: Double, action: Selector, state: Bool) {
            let check = NSButton(checkboxWithTitle: title, target: self, action: action)
            check.state = state ? .on : .off
            check.frame = NSRect(x: 20, y: y, width: 150, height: 24)
            modifiersBox.contentView?.addSubview(check)
        }
        
        addModCheck("Shift", y: 130, action: #selector(modShiftChanged(_:)), state: preferences.announceShift)
        addModCheck("Command", y: 100, action: #selector(modCommandChanged(_:)), state: preferences.announceCommand)
        addModCheck("Control", y: 70, action: #selector(modControlChanged(_:)), state: preferences.announceControl)
        addModCheck("Option", y: 40, action: #selector(modOptionChanged(_:)), state: preferences.announceOption)
        addModCheck("Caps Lock", y: 10, action: #selector(modCapsChanged(_:)), state: preferences.announceCapsLock)
        
        // Tab key
        let tabCheck = NSButton(checkboxWithTitle: "Tab", target: self, action: #selector(modTabChanged(_:)))
        tabCheck.state = preferences.announceTab ? .on : .off
        tabCheck.frame = NSRect(x: 180, y: 130, width: 100, height: 24)
        modifiersBox.contentView?.addSubview(tabCheck)
        
        typingItem.view = typingView
        tabView.addTabViewItem(typingItem)
        
        // Formatting Tab
        let formatItem = NSTabViewItem(identifier: "Formatting")
        formatItem.label = "Formatting"
        let formatView = NSView(frame: tabView.contentRect)
        
        func addFormatPopup(_ title: String, y: Double, index: Int, action: Selector) {
            addLabel(to: formatView, text: title, y: y, width: 140)
            let popup = NSPopUpButton(frame: NSRect(x: 160, y: y-2, width: 100, height: 24), pullsDown: false)
            popup.addItems(withTitles: ["None", "Speak", "Tone"]) // Assuming 0=None, 1=Speak, 2=Tone mapping in FeedbackStyle
             // Actually FeedbackStyle: 0=None, 1=Speak, 2=Tone.
            popup.selectItem(at: index)
            popup.target = self
            popup.action = action
            formatView.addSubview(popup)
        }
        
        addFormatPopup("Indentation:", y: 400, index: preferences.indentationFeedback.rawValue, action: #selector(indentChanged(_:)))
        addFormatPopup("Repeated Spaces:", y: 370, index: preferences.repeatedSpacesFeedback.rawValue, action: #selector(spacesChanged(_:)))
        addFormatPopup("Text Attributes:", y: 340, index: preferences.textAttributesFeedback.rawValue, action: #selector(attributesChanged(_:)))
        addFormatPopup("Misspelled Words:", y: 310, index: preferences.misspellingFeedback.rawValue, action: #selector(spellingChanged(_:)))
        
        formatItem.view = formatView
        tabView.addTabViewItem(formatItem)
        
        // Events Tab
        let eventItem = NSTabViewItem(identifier: "Events")
        eventItem.label = "Events"
        let eventView = NSView(frame: tabView.contentRect)
        
        let dialogCheck = NSButton(checkboxWithTitle: "Auto-speak Dialogs", target: self, action: #selector(dialogsChanged(_:)))
        dialogCheck.state = preferences.autoSpeakDialogs ? .on : .off
        dialogCheck.frame = NSRect(x: 20, y: 400, width: 250, height: 24)
        eventView.addSubview(dialogCheck)
        
        addLabel(to: eventView, text: "Progress Bar:", y: 370, width: 100)
        let progPopup = NSPopUpButton(frame: NSRect(x: 120, y: 368, width: 100, height: 24), pullsDown: false)
        progPopup.addItems(withTitles: ["None", "Speak", "Tone"]) // Map: 0=None, 1=Speak, 2=Tone? No, pref is FeedbackStyle.
        // Wait, progressFeedback default was .tone (2).
        // FeedbackStyle: none=0, speak=1, tone=2.
        // My popup order: None, Speak, Tone. Matches indices 0, 1, 2.
        progPopup.selectItem(at: preferences.progressFeedback.rawValue)
        progPopup.target = self
        progPopup.action = #selector(progressChanged(_:))
        eventView.addSubview(progPopup)
        
        let bgProgCheck = NSButton(checkboxWithTitle: "Speak Background Progress", target: self, action: #selector(bgProgressChanged(_:)))
        bgProgCheck.state = preferences.speakBackgroundProgress ? .on : .off
        bgProgCheck.frame = NSRect(x: 120, y: 340, width: 250, height: 24)
        eventView.addSubview(bgProgCheck)
        
        addLabel(to: eventView, text: "Table Rows:", y: 310, width: 100)
        let tablePopup = NSPopUpButton(frame: NSRect(x: 120, y: 308, width: 100, height: 24), pullsDown: false)
        tablePopup.addItems(withTitles: ["None", "Speak", "Tone"])
        tablePopup.selectItem(at: preferences.tableRowChangeFeedback.rawValue)
        tablePopup.target = self
        tablePopup.action = #selector(tableRowsChanged(_:))
        eventView.addSubview(tablePopup)
        
        eventItem.view = eventView
        tabView.addTabViewItem(eventItem)
        // Navigation Tab
        let navItem = NSTabViewItem(identifier: "Navigation")
        navItem.label = "Navigation"
        let navView = NSView(frame: tabView.contentRect)
        
        // Mouse Options
        let mouseFollowsCheck = NSButton(checkboxWithTitle: "Mouse follows Voice Cursor", target: self, action: #selector(mouseFollowsChanged(_:)))
        mouseFollowsCheck.state = preferences.mouseFollowsCursor ? .on : .off
        mouseFollowsCheck.frame = NSRect(x: 20, y: 410, width: 250, height: 24)
        navView.addSubview(mouseFollowsCheck)
        
        let cursorFollowsCheck = NSButton(checkboxWithTitle: "Voice Cursor follows Mouse", target: self, action: #selector(cursorFollowsChanged(_:)))
        cursorFollowsCheck.state = preferences.cursorFollowsMouse ? .on : .off
        cursorFollowsCheck.frame = NSRect(x: 20, y: 380, width: 250, height: 24)
        navView.addSubview(cursorFollowsCheck)
        
        let speakMouseCheck = NSButton(checkboxWithTitle: "Speak text under Mouse", target: self, action: #selector(speakMouseChanged(_:)))
        speakMouseCheck.state = preferences.speakTextUnderMouse ? .on : .off
        speakMouseCheck.frame = NSRect(x: 20, y: 350, width: 250, height: 24)
        navView.addSubview(speakMouseCheck)
        
        addLabel(to: navView, text: "Delay:", y: 320, width: 50)
        let mouseDelaySlider = NSSlider(value: preferences.speakUnderMouseDelay, minValue: 0.0, maxValue: 2.0, target: self, action: #selector(mouseDelayChanged(_:)))
        mouseDelaySlider.frame = NSRect(x: 70, y: 318, width: 150, height: 24)
        navView.addSubview(mouseDelaySlider)
        
        // Focus & Cursor
        addLabel(to: navView, text: "Initial Position:", y: 280, width: 100)
        let posPopup = NSPopUpButton(frame: NSRect(x: 120, y: 278, width: 100, height: 24), pullsDown: false)
        posPopup.addItems(withTitles: ["Focused Item", "First Item"])
        posPopup.selectItem(at: preferences.cursorInitialPosition)
        posPopup.target = self
        posPopup.action = #selector(initialPosChanged(_:))
        navView.addSubview(posPopup)
        
        let syncCheck = NSButton(checkboxWithTitle: "Synchronize Keyboard Focus", target: self, action: #selector(syncFocusChanged(_:)))
        syncCheck.state = preferences.syncFocus ? .on : .off
        syncCheck.frame = NSRect(x: 20, y: 250, width: 250, height: 24)
        navView.addSubview(syncCheck)
        
        let wrapCheck = NSButton(checkboxWithTitle: "Wrap Around", target: self, action: #selector(wrapChanged(_:)))
        wrapCheck.state = preferences.wrapAround ? .on : .off
        wrapCheck.frame = NSRect(x: 20, y: 220, width: 150, height: 24)
        navView.addSubview(wrapCheck)
        
        let tabInteractCheck = NSButton(checkboxWithTitle: "Auto-interact on Tab", target: self, action: #selector(tabInteractChanged(_:)))
        tabInteractCheck.state = preferences.autoInteractOnTab ? .on : .off
        tabInteractCheck.frame = NSRect(x: 180, y: 220, width: 150, height: 24)
        navView.addSubview(tabInteractCheck)
        
        // Existing Visuals/Haptics (Shifted down)
        let focusCheck = NSButton(checkboxWithTitle: "Visual Highlight", target: self, action: #selector(focusVisualsChanged(_:)))
        focusCheck.state = preferences.focusVisuals ? .on : .off
        focusCheck.frame = NSRect(x: 20, y: 180, width: 200, height: 24)
        navView.addSubview(focusCheck)
        
        let hapticCheck = NSButton(checkboxWithTitle: "Haptic Feedback", target: self, action: #selector(hapticsChanged(_:)))
        hapticCheck.state = preferences.hapticsEnabled ? .on : .off
        hapticCheck.frame = NSRect(x: 20, y: 150, width: 200, height: 24)
        navView.addSubview(hapticCheck)
        
        addLabel(to: navView, text: "Intensity:", y: 120, width: 70)
        let intensitySlider = NSSlider(value: Double(preferences.hapticIntensity), minValue: 0.1, maxValue: 2.0, target: self, action: #selector(intensityChanged(_:)))
        intensitySlider.frame = NSRect(x: 100, y: 118, width: 100, height: 24)
        navView.addSubview(intensitySlider)
        
        navItem.view = navView
        tabView.addTabViewItem(navItem)
        
        // Web Tab
        let webItem = NSTabViewItem(identifier: "Web")
        webItem.label = "Web"
        let webView = NSView(frame: tabView.contentRect)
        
        let layoutCheck = NSButton(checkboxWithTitle: "Document Layout (Virtual Buffer)", target: self, action: #selector(layoutChanged(_:)))
        layoutCheck.state = preferences.documentLayout ? .on : .off
        layoutCheck.frame = NSRect(x: 20, y: 400, width: 250, height: 24)
        webView.addSubview(layoutCheck)
        
        addLabel(to: webView, text: "Page Load Feedback:", y: 370, width: 140)
        let loadPopup = NSPopUpButton(frame: NSRect(x: 160, y: 368, width: 100, height: 24), pullsDown: false)
        loadPopup.addItems(withTitles: ["None", "Progress", "Tone"])
        loadPopup.selectItem(at: preferences.webLoadFeedback.rawValue)
        loadPopup.target = self
        loadPopup.action = #selector(webLoadChanged(_:))
        webView.addSubview(loadPopup)
        
        let summaryCheck = NSButton(checkboxWithTitle: "Speak Page Summary", target: self, action: #selector(webSummaryChanged(_:)))
        summaryCheck.state = preferences.speakWebSummary ? .on : .off
        summaryCheck.frame = NSRect(x: 20, y: 340, width: 250, height: 24)
        webView.addSubview(summaryCheck)
        
        let autoReadCheck = NSButton(checkboxWithTitle: "Auto-Read Page", target: self, action: #selector(webAutoReadChanged(_:)))
        autoReadCheck.state = preferences.autoReadWebPage ? .on : .off
        autoReadCheck.frame = NSRect(x: 20, y: 310, width: 250, height: 24)
        webView.addSubview(autoReadCheck)
        
        webItem.view = webView
        tabView.addTabViewItem(webItem)

        // Vision Tab
        let visionItem = NSTabViewItem(identifier: "Vision")
        visionItem.label = "Vision"
        let visionView = NSView(frame: tabView.contentRect)
        
        let curtainCheck = NSButton(checkboxWithTitle: "Screen Curtain", target: self, action: #selector(curtainChanged(_:)))
        curtainCheck.state = preferences.screenCurtain ? .on : .off
        curtainCheck.frame = NSRect(x: 20, y: 220, width: 200, height: 24)
        visionView.addSubview(curtainCheck)
        
        // Vision - OCR
        let ocrLabel = NSTextField(labelWithString: "OCR Language:")
        ocrLabel.frame = NSRect(x: 20, y: 180, width: 100, height: 20)
        visionView.addSubview(ocrLabel)
        
        let ocrPopup = NSPopUpButton(frame: NSRect(x: 130, y: 178, width: 150, height: 24), pullsDown: false)
        ocrPopup.addItems(withTitles: ["English", "Spanish", "French", "German"])
        if let idx = ocrPopup.itemArray.firstIndex(where: { $0.title == preferences.ocrLanguage }) {
             ocrPopup.selectItem(at: idx)
        }
        ocrPopup.target = self
        ocrPopup.action = #selector(ocrChanged(_:))
        visionView.addSubview(ocrPopup)
        
        visionItem.view = visionView
        tabView.addTabViewItem(visionItem)

        // Braille Tab
        let brailleItem = NSTabViewItem(identifier: "Braille")
        brailleItem.label = "Braille"
        let brailleView = NSView(frame: tabView.contentRect)
        let brailleCheck = NSButton(checkboxWithTitle: "Enable Virtual Display", target: self, action: #selector(brailleChanged(_:)))
        brailleCheck.state = preferences.brailleEnabled ? .on : .off
        brailleCheck.frame = NSRect(x: 20, y: 220, width: 200, height: 24)
        brailleView.addSubview(brailleCheck)
        
        // Braille - Table
        let brLabel = NSTextField(labelWithString: "Translation Table:")
        brLabel.frame = NSRect(x: 20, y: 180, width: 120, height: 20)
        brailleView.addSubview(brLabel)
        
        let brPopup = NSPopUpButton(frame: NSRect(x: 140, y: 178, width: 150, height: 24), pullsDown: false)
        brPopup.addItems(withTitles: ["English Grade 1", "English Grade 2", "UEB Grade 1", "UEB Grade 2"])
        if let idx = brPopup.itemArray.firstIndex(where: { $0.title == preferences.brailleTranslationTable }) {
             brPopup.selectItem(at: idx)
        }
        brPopup.target = self
        brPopup.action = #selector(brTableChanged(_:))
        brailleView.addSubview(brPopup)
        
        brailleItem.view = brailleView
        tabView.addTabViewItem(brailleItem)
        
        // Shortcuts Tab
        let keysItem = NSTabViewItem(identifier: "Shortcuts")
        keysItem.label = "Shortcuts"
        let keysView = NSView(frame: tabView.contentRect)
        
        let resetBtn = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetShortcuts(_:)))
        resetBtn.frame = NSRect(x: 20, y: 450, width: 150, height: 24)
        keysView.addSubview(resetBtn)
        
        addLabel(to: keysView, text: "Current Mapping (Read Only):", y: 420, width: 200)
        
        let keysScroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 400, height: 390))
        keysScroll.hasVerticalScroller = true
        let keysContent = NSTextView(frame: keysScroll.bounds)
        keysContent.isEditable = false
        // Load mappings
        let mapping = preferences.keyMapping
        let mappingText = mapping.sorted(by: { $0.key < $1.key }).map { "\($0.key): KeyCode \($0.value.keyCode) Mods \($0.value.modifiers)" }.joined(separator: "\n")
        keysContent.string = mappingText.isEmpty ? "Default System Bindings Active (Not explicitly mapped)" : mappingText
        
        keysScroll.documentView = keysContent
        keysView.addSubview(keysScroll)
        
        keysItem.view = keysView
        tabView.addTabViewItem(keysItem)
        
        // Pronunciations Tab
        let prItem = NSTabViewItem(identifier: "Pronunciations")
        prItem.label = "Pronounce"
        let prView = NSView(frame: tabView.contentRect)
        
        addLabel(to: prView, text: "Format: original=replacement", y: 450, width: 250)
        
        let prScroll = NSScrollView(frame: NSRect(x: 20, y: 60, width: 400, height: 380))
        prScroll.hasVerticalScroller = true
        let prContent = NSTextView(frame: prScroll.bounds)
        prContent.isEditable = true
        prContent.isRichText = false
        
        let prDict = preferences.pronunciations
        let prText = prDict.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
        prContent.string = prText
        self.pronunciationTextView = prContent // Save ref
        
        prScroll.documentView = prContent
        prView.addSubview(prScroll)
        
        let savePrBtn = NSButton(title: "Save Changes", target: self, action: #selector(savePronunciations(_:)))
        savePrBtn.frame = NSRect(x: 320, y: 20, width: 100, height: 24)
        prView.addSubview(savePrBtn)
        
        prItem.view = prView
        tabView.addTabViewItem(prItem)
        
        // Gestures Tab
        let gestItem = NSTabViewItem(identifier: "Gestures")
        gestItem.label = "Gestures"
        let gestView = NSView(frame: tabView.contentRect)
        
        addLabel(to: gestView, text: "Mapped Gestures (Read Only):", y: 450, width: 250)
        
        let gestScroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 400, height: 420))
        gestScroll.hasVerticalScroller = true
        let gestContent = NSTextView(frame: gestScroll.bounds)
        gestContent.isEditable = false
        
        let gestDict = preferences.gestureMapping
        let gestText = gestDict.sorted(by: { $0.key < $1.key }).map { "\($0.key) -> \($0.value)" }.joined(separator: "\n")
        gestContent.string = gestText.isEmpty ? "No explicit mappings (Defaults active)" : gestText
        
        gestScroll.documentView = gestContent
        gestView.addSubview(gestScroll)
        
        gestItem.view = gestView
        tabView.addTabViewItem(gestItem)
        
        contentView.addSubview(tabView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Brings the settings window to the foreground and makes it key.
    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Helper to add a label text field to a view at a specific position.
    private func addLabel(to view: NSView, text: String, y: Double, width: Double = 100) {
        let label = NSTextField(labelWithString: text)
        label.frame = NSRect(x: 20, y: y, width: width, height: 20)
        view.addSubview(label)
    }
    
    @objc private func duckingChanged(_ sender: NSButton) {
        preferences.audioDucking = sender.state == .on
    }
    
    @objc private func rateChanged(_ sender: NSSlider) {
        preferences.speechRate = Float(sender.doubleValue)
    }
    
    @objc private func volumeChanged(_ sender: NSSlider) {
        preferences.speechVolume = Float(sender.doubleValue)
    }
    
    @objc private func pitchChanged(_ sender: NSSlider) {
        preferences.pitch = Float(sender.doubleValue)
    }

    @objc private func confirmExitChanged(_ sender: NSButton) {
        preferences.confirmOnExit = (sender.state == .on)
    }
    
    @objc private func autoFocusChanged(_ sender: NSButton) {
        preferences.intelligentAutoFocus = (sender.state == .on)
    }
    
    @objc private func spatialChanged(_ sender: NSButton) {
        preferences.spatialAudioEnabled = sender.state == .on
    }
    
    @objc private func widthChanged(_ sender: NSSlider) {
        preferences.stereoWidth = Float(sender.doubleValue)
    }
    
    @objc private func reverbChanged(_ sender: NSPopUpButton) {
        preferences.reverbPreset = sender.indexOfSelectedItem
    }
    
    @objc private func voiceChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        // Very inefficient lookup lol
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let voice = voices.first(where: { "\($0.name) (\($0.language))" == title }) {
            preferences.selectedVoiceIdentifier = voice.identifier
        }
    }
    
    @objc private func kbLayoutChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        preferences.keyboardLayout = title
    }
    
    @objc private func sleepChanged(_ sender: NSButton) {
        preferences.sleepMode = sender.state == .on
    }
    
    @objc private func ocrChanged(_ sender: NSPopUpButton) {
         guard let title = sender.selectedItem?.title else { return }
         preferences.ocrLanguage = title
    }
    
    @objc private func brTableChanged(_ sender: NSPopUpButton) {
         guard let title = sender.selectedItem?.title else { return }
         preferences.brailleTranslationTable = title
    }
    
    @objc private func loginChanged(_ sender: NSButton) {
        preferences.startAtLogin = sender.state == .on
    }
    
    @objc private func mouseChanged(_ sender: NSButton) {
        preferences.mouseTracking = sender.state == .on
    }
    
    @objc private func focusVisualsChanged(_ sender: NSButton) {
        preferences.focusVisuals = sender.state == .on
    }
    
    @objc private func hapticsChanged(_ sender: NSButton) {
        preferences.hapticsEnabled = sender.state == .on
    }
    
    @objc private func intensityChanged(_ sender: NSSlider) {
        preferences.hapticIntensity = Float(sender.doubleValue)
    }
    
    @objc private func layoutChanged(_ sender: NSButton) {
        preferences.documentLayout = sender.state == .on
    }
    
    @objc private func curtainChanged(_ sender: NSButton) {
        preferences.screenCurtain = sender.state == .on
    }

    @objc private func brailleChanged(_ sender: NSButton) {
        preferences.brailleEnabled = sender.state == .on
        if preferences.brailleEnabled {
             if !BrailleService.shared.isEnabled { BrailleService.shared.toggle() }
        } else {
             if BrailleService.shared.isEnabled { BrailleService.shared.toggle() }
        }
    }
    // Pronunciation Tab
    @objc private func savePronunciations(_ sender: NSButton) {
        guard let text = pronunciationTextView?.string else { return }
        var newDict = [String: String]()
        text.enumerateLines { line, _ in
            let parts = line.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty && !val.isEmpty {
                    newDict[key] = val
                }
            }
        }
        preferences.pronunciations = newDict
    }
    
    // Shortcuts Tab
    @objc private func resetShortcuts(_ sender: NSButton) {
        preferences.keyMapping = [:] // Triggers default
    }

    private var pronunciationTextView: NSTextView?
    
    // MARK: - Handlers
    
    // The following methods are action handlers for UI controls, bridging user interactions
    // to the underlying `Preferences` singleton.
    
    // Speech
    @objc private func verbosityChanged(_ sender: NSPopUpButton) { preferences.verbosityLevel = Preferences.VerbosityLevel(rawValue: sender.indexOfSelectedItem) ?? .medium }
    @objc private func punctChanged(_ sender: NSPopUpButton) { preferences.punctuationMode = Preferences.PunctuationMode(rawValue: sender.indexOfSelectedItem) ?? .some }
    @objc private func capPitchChanged(_ sender: NSSlider) { preferences.capPitchChange = Float(sender.doubleValue) }
    @objc private func speakCapChanged(_ sender: NSButton) { preferences.speakCap = sender.state == .on }

    @objc private func numStyleChanged(_ sender: NSPopUpButton) { preferences.numberStyle = Preferences.NumberReadingStyle(rawValue: sender.indexOfSelectedItem) ?? .words }
    
    // Typing
    @objc private func typingEchoChanged(_ sender: NSPopUpButton) { preferences.typingEcho = Preferences.TypingEcho(rawValue: sender.indexOfSelectedItem) ?? .words }
    @objc private func deletionFeedbackChanged(_ sender: NSPopUpButton) { preferences.deletionFeedback = Preferences.DeletionFeedback(rawValue: sender.indexOfSelectedItem) ?? .speak }
    @objc private func modShiftChanged(_ sender: NSButton) { preferences.announceShift = sender.state == .on }
    @objc private func modCommandChanged(_ sender: NSButton) { preferences.announceCommand = sender.state == .on }
    @objc private func modControlChanged(_ sender: NSButton) { preferences.announceControl = sender.state == .on }
    @objc private func modOptionChanged(_ sender: NSButton) { preferences.announceOption = sender.state == .on }
    @objc private func modCapsChanged(_ sender: NSButton) { preferences.announceCapsLock = sender.state == .on }
    @objc private func modTabChanged(_ sender: NSButton) { preferences.announceTab = sender.state == .on }
    
    // Formatting
    @objc private func indentChanged(_ sender: NSPopUpButton) { preferences.indentationFeedback = Preferences.FeedbackStyle(rawValue: sender.indexOfSelectedItem) ?? .speak }
    @objc private func spacesChanged(_ sender: NSPopUpButton) { preferences.repeatedSpacesFeedback = Preferences.FeedbackStyle(rawValue: sender.indexOfSelectedItem) ?? .none }
    @objc private func attributesChanged(_ sender: NSPopUpButton) { preferences.textAttributesFeedback = Preferences.FeedbackStyle(rawValue: sender.indexOfSelectedItem) ?? .speak }
    @objc private func spellingChanged(_ sender: NSPopUpButton) { preferences.misspellingFeedback = Preferences.FeedbackStyle(rawValue: sender.indexOfSelectedItem) ?? .speak }
    
    // Events
    @objc private func dialogsChanged(_ sender: NSButton) { preferences.autoSpeakDialogs = sender.state == .on }
    @objc private func progressChanged(_ sender: NSPopUpButton) { preferences.progressFeedback = Preferences.FeedbackStyle(rawValue: sender.indexOfSelectedItem) ?? .tone }
    @objc private func bgProgressChanged(_ sender: NSButton) { preferences.speakBackgroundProgress = sender.state == .on }
    @objc private func tableRowsChanged(_ sender: NSPopUpButton) { preferences.tableRowChangeFeedback = Preferences.FeedbackStyle(rawValue: sender.indexOfSelectedItem) ?? .speak }
    
    // Navigation
    @objc private func mouseFollowsChanged(_ sender: NSButton) { preferences.mouseFollowsCursor = sender.state == .on }
    @objc private func cursorFollowsChanged(_ sender: NSButton) { preferences.cursorFollowsMouse = sender.state == .on }
    @objc private func speakMouseChanged(_ sender: NSButton) { preferences.speakTextUnderMouse = sender.state == .on }
    @objc private func mouseDelayChanged(_ sender: NSSlider) { preferences.speakUnderMouseDelay = sender.doubleValue }
    @objc private func initialPosChanged(_ sender: NSPopUpButton) { preferences.cursorInitialPosition = sender.indexOfSelectedItem }
    @objc private func syncFocusChanged(_ sender: NSButton) { preferences.syncFocus = sender.state == .on }
    @objc private func wrapChanged(_ sender: NSButton) { preferences.wrapAround = sender.state == .on }
    @objc private func tabInteractChanged(_ sender: NSButton) { preferences.autoInteractOnTab = sender.state == .on }
    
    // Input Tab
    @objc private func numpadCmdChanged(_ sender: NSButton) { preferences.numpadCommanderEnabled = sender.state == .on }
    @objc private func voshCapChanged(_ sender: NSButton) { 
        if sender.state == .on { preferences.voshModifiers.insert(.capsLock) }
        else { preferences.voshModifiers.remove(.capsLock) }
    }
    @objc private func voshNumChanged(_ sender: NSButton) { 
        if sender.state == .on { preferences.voshModifiers.insert(.numpad0) }
        else { preferences.voshModifiers.remove(.numpad0) }
    }
    @objc private func voshCtrlOptChanged(_ sender: NSButton) {
        if sender.state == .on { preferences.voshModifiers.insert(.ctrlOption) }
        else { preferences.voshModifiers.remove(.ctrlOption) }
    }
    
    // Web
    @objc private func webLoadChanged(_ sender: NSPopUpButton) { preferences.webLoadFeedback = Preferences.WebLoadFeedback(rawValue: sender.indexOfSelectedItem) ?? .tone }
    @objc private func webSummaryChanged(_ sender: NSButton) { preferences.speakWebSummary = sender.state == .on }
    @objc private func webAutoReadChanged(_ sender: NSButton) { preferences.autoReadWebPage = sender.state == .on }
    
    // General - Greeting/Goodbye
    @objc private func greetingChanged(_ sender: NSTextField) { preferences.greetingMessage = sender.stringValue }
    @objc private func goodbyeChanged(_ sender: NSTextField) { preferences.goodbyeMessage = sender.stringValue }
}
