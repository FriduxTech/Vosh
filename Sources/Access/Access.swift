//
//  Access.swift
//  Vosh
//
//  Created by Vosh Team.
//

import AppKit
import OSLog

import Element
import Output

/// The main entry point for the Vosh accessibility system.
///
/// This class acts as the central coordinator for managing accessibility focus,
/// processing accessibility events, and interacting with the system wide accessibility element.
/// It maintains the state of the active application, the current user focus, and handles
/// navigation and interaction logic.
@AccessActor public final class Access {
    /// The system-wide accessibility element representing the entire screen/OS.
    private let system: Element
    
    /// The currently active application element.
    public private(set) var application: Element?
    
    /// The process identifier (PID) of the currently active application.
    private var processIdentifier: pid_t = 0
    
    /// Observer for accessibility events from the active application.
    private var observer: ElementObserver?
    
    /// The current accessibility focus of the user.
    ///
    /// When this property changes, any registered `onCustomFocusChange` callback is triggered,
    /// and the review cursor is updated if `reviewFollowsFocus` is enabled.
    public private(set) var focus: AccessFocus? {
        didSet {
            if let f = focus {
                 Task { await onCustomFocusChange?(f) }
            }
            if reviewFollowsFocus {
                reviewFocus = focus
            }
        }
    }
    
    /// The independent review cursor used for exploring content without moving the system focus.
    ///
    /// This is used for "Review Mode" or "Browse Mode" where the user can read content
    /// line-by-line or character-by-character.
    public private(set) var reviewFocus: AccessFocus? {
        didSet {
            if let r = reviewFocus {
                 Task { await onCustomReviewChange?(r) }
            }
        }
    }
    
    /// Determines whether the review cursor should automatically update to match the system focus.
    /// Defaults to `true`.
    public var reviewFollowsFocus: Bool = true
    
    /// Determines whether the system focus should automatically follow the review cursor.
    /// Defaults to `false`.
    public var focusFollowsReview: Bool = false
    
    // MARK: - Callbacks
    
    /// Callback triggered when the system focus changes.
    public var onCustomFocusChange: ((AccessFocus) async -> Void)?
    
    /// Callback triggered when the review focus changes.
    public var onCustomReviewChange: ((AccessFocus) async -> Void)?
    
    /// A map to persist the last focused element for each application PID.
    /// Used to restore focus when switching back to an application.
    private var appFocusMap = [pid_t: Element]()
    
    /// Indicates whether mouse tracking/routing is enabled.
    public var isMouseTrackingEnabled = false
    
    /// Enables or disables mouse tracking.
    ///
    /// - Parameter enabled: `true` to enable mouse tracking, `false` to disable.
    public func setMouseTracking(_ enabled: Bool) {
        self.isMouseTrackingEnabled = enabled
    }
    
    // MARK: - Configuration
    
    /// Automatically read dialogs when they appear.
    public var autoSpeakDialogs: Bool = false
    
    /// Feedback style for progress updates (1 = Tone, 2 = Speak).
    public var progressFeedback: Int = 1
    
    /// Whether to announce progress updates for background windows.
    public var speakBackgroundProgress: Bool = false
    
    /// Feedback style for table row changes (1 = Speak, 2 = Tone).
    public var tableRowChangeFeedback: Int = 1
    
    /// Whether to use intelligent algorithms to find the best initial focus in a window.
    public var intelligentAutoFocus: Bool = true
    
    /// Observer for the frontmost application change.
    private var refocusTrigger: NSKeyValueObservation?
    
    /// Shared logger for the Access module.
    private static let logger = Logger()

    /// Initializes the accessibility framework.
    ///
    /// This initializer sets up the system-wide element connection, starts the event loop,
    /// and begins observing the frontmost application to manage focus.
    ///
    /// - Returns: An initialized `Access` instance, or `nil` if the process is not trusted
    ///            by the accessibility system.
    public init?() async {
        guard await Element.confirmProcessTrustedStatus() else {
            return nil
        }
        system = await Element()
        
        // Start the event handling loop
        Task() {[weak self] in
            while let self = self {
                var eventIterator = await self.observer?.eventStream.makeAsyncIterator()
                while let event = await eventIterator?.next() {
                    await handleEvent(event)
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        // Focus initial application
        await refocus(processIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier)
        
        // Observe application switching
        refocusTrigger = NSWorkspace.shared.observe(\.frontmostApplication, options: .new) {[weak self] (_, value) in
            guard let runningApplication = value.newValue else {
                return
            }
            let processIdentifier = runningApplication?.processIdentifier
            Task {[self] in
                await self?.refocus(processIdentifier: processIdentifier)
            }
        }
    }

    /// Sets the response timeout for accessibility requests.
    ///
    /// - Parameter seconds: The timeout duration in seconds.
    public func setTimeout(seconds: Float) async {
        do {
            try await system.setTimeout(seconds: seconds)
        } catch {
            await handleError(error)
        }
    }

    private var onFormsModeRequest: (@Sendable (Bool) -> Void)?
    
    /// Sets the callback for Forms Mode requests.
    ///
    /// This callback is invoked when the focus moves to an editable field (requesting true)
    /// or leaves a web area (requesting false).
    ///
    /// - Parameter handler: The closure to handle the request.
    public func setFormsModeRequest(_ handler: @escaping @Sendable (Bool) -> Void) {
        self.onFormsModeRequest = handler
    }

    /// Reads the content of the currently focused element.
    ///
    /// This method orchestrates the reading process:
    /// 1. Checks for web content context.
    /// 2. Determines if "Forms Mode" or "Browse Mode" is applicable.
    /// 3. Executes custom focus handlers if present.
    /// 4. Reads the element using its `AccessReader`.
    /// 5. Updates spatial audio context.
    /// 6. Conveys the output via `Output`.
    /// 7. Updates the visual inspector.
    public func readFocus() async {
        do {
            guard let focus = focus else {
                let content = [OutputSemantic.noFocus]
                await Output.shared.convey(content)
                return
            }
            
            // Check Web Context
            await checkForWebArea()
            
            // Web / Browse Mode Logic
            if let role = try? await focus.entity.element.getAttribute(.role) as? ElementRole {
                 if role == .textField || role == .textArea {
                     // Auto-Forms Mode: Request Entry (true)
                     onFormsModeRequest?(true)
                 } else {
                     // Browse Mode: Request Exit (false) if in web
                     if webAccess != nil {
                         onFormsModeRequest?(false)
                     }
                 }
            }
            
            // Custom Module Logic
            if let customHandler = onCustomFocus {
                if await customHandler(focus) {
                    await updateInspector()
                    if isMouseTrackingEnabled {
                         await moveMouseToFocus(click: false)
                    }
                    return
                }
            }
            
            let content = try await focus.reader.read()
            
            // Spatial Audio Update
            await updateSpatialContext()
            
            await Output.shared.convey(content)
            await updateInspector()
            
            if isMouseTrackingEnabled {
                 await moveMouseToFocus(click: false)
            }
        } catch {
            await handleError(error)
        }
    }
    
    /// Updates the spatial position of the audio output based on the focused element's location.
    private func updateSpatialContext() async {
        guard let focus = focus else { return }
        do {
            if let position = try await focus.entity.element.getAttribute(.position) as? CGPoint,
               let size = try await focus.entity.element.getAttribute(.size) as? CGSize {
                
                let midX = position.x + size.width / 2.0
                
                // Fetch Screen Width safely
                let width = await MainActor.run { return NSScreen.main?.frame.width ?? 1920.0 }
                
                let normalized = max(0.0, min(1.0, midX / width))
                await Output.shared.setSpatialPosition(normalized)
            }
        } catch {}
    }
    
    /// Updates the Vosh Inspector with details about the current focus.
    private func updateInspector() async {
        guard let focus = focus else {
             await VoshInspector.shared.update(info: "No Focus")
             return
        }
        do {
            let role = try? await focus.entity.element.getAttribute(.role) as? ElementRole
            let title = try? await focus.entity.element.getAttribute(.title) as? String
            let desc = try? await focus.entity.element.getAttribute(.description) as? String
            let value = try? await focus.entity.element.getAttribute(.value) as? String 
            
            let info = """
            Role: \(role?.rawValue ?? "Unknown")
            Title: \(title ?? "nil")
            Description: \(desc ?? "nil")
            Value: \(value ?? "nil")
            """
            await VoshInspector.shared.update(info: info)
        }
    }

    /// Handler for custom focus logic, typically used by App Modules.
    /// Returns `true` if the focus was handled by the module, preventing default behavior.
    public var onCustomFocus: ((AccessFocus) async -> Bool)?
    
    /// Sets the custom focus handler.
    ///
    /// - Parameter handler: The closure to handle custom focus logic.
    public func setCustomFocusHandler(_ handler: @escaping (AccessFocus) async -> Bool) {
        self.onCustomFocus = handler
    }
    
    /// Moves the system focus to the parent of the current element.
    public func focusParent() async {
        do {
            guard let oldFocus = focus else {
                let content = [OutputSemantic.noFocus]
                await Output.shared.convey(content)
                return
            }
            guard let parent = try await oldFocus.entity.getParent() else {
                var content = [OutputSemantic.boundary]
                content.append(contentsOf: try await oldFocus.reader.read())
                await Output.shared.convey(content)
                return
            }
            let newFocus = try await AccessFocus(on: parent)
            self.focus = newFocus
            try await newFocus.entity.setKeyboardFocus()
            var content = [OutputSemantic.exiting]
            content.append(contentsOf: try await newFocus.reader.readSummary())
            await Output.shared.convey(content)
        } catch {
            await handleError(error)
        }
    }

    // MARK: - Navigation Extensions
    
    // Configuration properties for navigation and mouse behavior
    public var speakTextUnderMouse: Bool = false
    public var speakUnderMouseDelay: Double = 0.0
    public var mouseFollowsCursor: Bool = false
    public var cursorFollowsMouse: Bool = false
    public var syncFocus: Bool = true
    public var wrapAround: Bool = true
    
    /// Defines the initial cursor position strategy:
    /// 0 = Default (Last focused), 1 = First Child of Window.
    public var cursorInitialPosition: Int = 0
    
    // Web Configuration
    public var webLoadFeedback: Int = 2 // 1 = Speak, 2 = Tone
    public var speakWebSummary: Bool = false
    public var autoReadWebPage: Bool = false

    /// Moves the focus to the next or previous sibling element.
    ///
    /// This method implements complex logic to determine the "next" meaningful element, including:
    /// - Normal sibling navigation.
    /// - Interaction with Math content.
    /// - Wrapping around at boundaries (if enabled).
    /// - Syncing keyboard focus.
    ///
    /// - Parameter backwards: If `true`, moves to the previous sibling; otherwise, moves to the next.
    public func focusNextSibling(backwards: Bool) async {
        do {
            guard let oldFocus = focus else {
                let content = [OutputSemantic.noFocus]
                await Output.shared.convey(content)
                return
            }
            var sibling = try await oldFocus.entity.getNextSibling(backwards: backwards)
            
            // Math Sibling Fallback ... (omitted for brevity in search/replace match if possible, but strict match needed)
            // Re-implementing math fallback to be safe
            if sibling == nil,
               let parent = try? await oldFocus.entity.getParent(),
               (try? await parent.element.getAttribute(.role) as? ElementRole) == .math {
                   let math = AccessMath(root: parent.element)
                   let kids = await math.getChildren()
                   if let idx = kids.firstIndex(where: { $0 == oldFocus.entity.element }) {
                       let nextIdx = backwards ? idx - 1 : idx + 1
                       if kids.indices.contains(nextIdx) {
                           sibling = try? await AccessEntity(for: kids[nextIdx])
                       }
                   }
            }
            
            // Wrap Around Logic
            if sibling == nil && wrapAround {
                if let parent = try? await oldFocus.entity.getParent() {
                    // Backwards loops to Last Child
                    // Forwards loops to First Child
                    // AccessEntity needs getLastChild helper? 
                    // getFirstChild is available.
                    if backwards {
                         // getLastChild not implemented in public API usually? 
                         // AccessEntity is wrapper.
                         // Optimization: Get children list.
                         if let children = try? await parent.element.getAttribute(.childElements) as? [Element], !children.isEmpty {
                              sibling = try? await AccessEntity(for: children.last!)
                         }
                    } else {
                         // First child
                        if let first = try? await parent.getFirstChild() {
                            sibling = first
                        }
                    }
                }
            }
            
            guard let foundSibling = sibling else {
                var content = [OutputSemantic.boundary]
                content.append(contentsOf: try await oldFocus.reader.read())
                await Output.shared.convey(content)
                return
            }
            let newFocus = try await AccessFocus(on: foundSibling)
            self.focus = newFocus
            
            if syncFocus {
                 try await newFocus.entity.setKeyboardFocus()
            }
            
            var content = [!backwards ? OutputSemantic.next : OutputSemantic.previous]
            content.append(contentsOf: try await newFocus.reader.read())
            await Output.shared.convey(content)
            await attemptSmartInteraction()
        } catch {
            await handleError(error)
        }
    }

    /// Moves the focus to the first child of the current element.
    ///
    /// Useful for drilling down into containers like lists, tables, or groups.
    /// Special handling is included for Math content.
    public func focusFirstChild() async {
        do {
            guard let oldFocus = focus else {
                let content = [OutputSemantic.noFocus]
                await Output.shared.convey(content)
                return
            }
            
            // Math Support
            let role = try? await oldFocus.entity.element.getAttribute(.role) as? ElementRole
            if role == .math {
                let math = AccessMath(root: oldFocus.entity.element)
                let kids = await math.getChildren()
                if let child = kids.first {
                    let newFocus = try await AccessFocus(on: child)
                    self.focus = newFocus
                    // Don't set keyboard focus on math sub-elements usually?
                    // try await newFocus.entity.setKeyboardFocus()
                    var content = [OutputSemantic.entering]
                    content.append(contentsOf: try await oldFocus.reader.readSummary()) // "Math"
                    content.append(contentsOf: try await newFocus.reader.read()) // "Numerator..."
                    await Output.shared.convey(content)
                    return
                }
            }
            
            guard let child = try await oldFocus.entity.getFirstChild() else {
                var content = [OutputSemantic.boundary]
                content.append(contentsOf: try await oldFocus.reader.read())
                await Output.shared.convey(content)
                return
            }
            let newFocus = try await AccessFocus(on: child)
            self.focus = newFocus
            try await newFocus.entity.setKeyboardFocus()
            var content = [OutputSemantic.entering]
            content.append(contentsOf: try await oldFocus.reader.readSummary())
            content.append(contentsOf: try await newFocus.reader.read())
            await Output.shared.convey(content)
            
            // Recursively attempt to drill down if the new child is also a wrapper
            await attemptSmartInteraction()
        } catch {
            await handleError(error)
        }
    }

    /// Dumps the system wide element to a property list file chosen by the user.
    @MainActor public func dumpSystemWide() async {
        await dumpElement(system)
    }

    /// Dumps all accessibility elements of the currently active application to a property list file chosen by the user.
    @MainActor public func dumpApplication() async {
        guard let application = await application else {
            let content = [OutputSemantic.noFocus]
            Output.shared.convey(content)
            return
        }
        await dumpElement(application)
    }

    /// Dumps all descendant accessibility elements of the currently focused element to a property list file chosen by the user.
    @MainActor public func dumpFocus() async {
        guard let focus = await focus else {
            let content = [OutputSemantic.noFocus]
            Output.shared.convey(content)
            return
        }
        await dumpElement(focus.entity.element)
    }

    /// Resets or updates the focus based on the active application and process identifier.
    ///
    /// This method handles:
    /// - Switching observation to a new application.
    /// - Restoring the last focused element for that application.
    /// - Falling back to a default focus strategy (e.g., focused window or first child) if no history exists.
    ///
    /// - Parameter processIdentifier: The PID of the application to focus. If `nil`, clears the focus.
    private func refocus(processIdentifier: pid_t?) async {
        do {
            // Save current focus
            if let currentApp = application, let currentFocus = focus {
                 appFocusMap[self.processIdentifier] = currentFocus.entity.element
            }
            
            guard let processIdentifier = processIdentifier else {
                application = nil
                self.processIdentifier = 0
                application = nil
                self.processIdentifier = 0
                await observer?.invalidate()
                observer = nil
                focus = nil
                focus = nil
                let content = [OutputSemantic.noFocus]
                await Output.shared.convey(content)
                return
            }
            var content = [OutputSemantic]()
            if processIdentifier != self.processIdentifier {
                let application = await Element(processIdentifier: processIdentifier)
                let observer = try await ElementObserver(element: application)
                try await observer.subscribe(to: .applicationDidAnnounce)
                try await observer.subscribe(to: .elementDidDisappear)
                try await observer.subscribe(to: .elementDidGetFocus)
                try await observer.subscribe(to: .windowDidAppear)
                try await observer.subscribe(to: .valueDidUpdate)
                try await observer.subscribe(to: .rowCountDidUpdate)
                try await observer.subscribe(to: .loadComplete)
                self.application = application
                self.processIdentifier = processIdentifier
                try await observer.subscribe(to: .loadComplete)
                self.application = application
                self.processIdentifier = processIdentifier
                await self.observer?.invalidate()
                self.observer = observer
                let applicationLabel = try await application.getAttribute(.title) as? String
                content.append(.application(applicationLabel ?? "Application"))
            }
            guard let application = self.application, let observer = self.observer else {
                fatalError("Logic failed")
            }
            
            // Check persistence first
            var didRefocus = false
            if let saved = appFocusMap[processIdentifier] {
                 // Try to restore
                 // Verify it still exists?
                 // Just try to create AccessFocus.
                 if let focus = try? await AccessFocus(on: saved) {
                     self.focus = focus
                     // Must explicitly set keyboard focus back if needed? 
                     // Usually app switch handles window, but precise element might need logic.
                     // On macOS, just selecting the app usually focuses the last element if standard.
                     // But if we want to force our own cursor:
                     // try? await saved.setKeyboardFocus() // Might be aggressive
                     
                     // Read summary
                     if let window = try? await saved.getAttribute(.windowElement) as? Element,
                        let label = try? await window.getAttribute(.title) as? String {
                         content.append(.window(label))
                     }
                     content.append(contentsOf: try await focus.reader.read())
                     didRefocus = true
                 }
            }
            
            var targetEntity: AccessEntity? // Define in outer scope
            
            if !didRefocus {
                // Determine Goal
                var windowElement: Element?
                
                // Try getting focused window first
                if let w = try? await application.getAttribute(.focusedWindow) as? Element {
                    windowElement = w
                }
                
                // If preference is First Item (1), try window first child
                if cursorInitialPosition == 1, let w = windowElement {
                    targetEntity = try? await AccessEntity(for: w).getFirstChild()
                }
                
                // If not set, or no child found, try keyboard focus
                if targetEntity == nil {
                    if let k = try? await application.getAttribute(.focusedElement) as? Element {
                        targetEntity = try? await AccessEntity(for: k)
                        // Update window if we didn't have it
                        if windowElement == nil { windowElement = try? await k.getAttribute(.windowElement) as? Element }
                    }
                }
                
                // Fallback: If still no target, try window first child again (if we skipped it or didn't try)
                if targetEntity == nil, let w = windowElement {
                     targetEntity = try? await AccessEntity(for: w).getFirstChild()
                }
                
                if let entity = targetEntity {
                    if let window = windowElement {
                        if let windowLabel = try? await window.getAttribute(.title) as? String, !windowLabel.isEmpty {
                            content.append(.window(windowLabel))
                        } else {
                            content.append(.window("Untitled"))
                        }
                    }
                    
                    let focus = try await AccessFocus(on: entity)
                    self.focus = focus
                    let readContent = try await focus.reader.read()
                    
                    // Race Condition Check: Verify focus hasn't changed while we were reading
                    if self.focus?.id == focus.id {
                        content.append(contentsOf: readContent)
                    }
                } else {
                    self.focus = nil
                    try await observer.subscribe(to: .elementDidAppear)
                    content.append(.noFocus)
                }
            }
            
            // Final check before speaking
            if !content.isEmpty {
                await Output.shared.convey(content)
            }
            // Only attempt interaction if we are still focused on what we think we are
            // We use the optional binding from earlier if it existed, otherwise we skip
            if let f = self.focus, let t = targetEntity, f.entity.element == t.element {
                 await attemptSmartInteraction()
            } else if targetEntity == nil, let f = self.focus {
                 // If we didn't have a targetEntity var in scope (unlikely in this block structure but possible if logic split),
                 // we might still want to try.
                 // But in this specific flow, targetEntity is defined in the else block above...
                 // Actually, targetEntity is defined INSIDE the else block of `if !didRefocus`.
                 // If `didRefocus` was true, targetEntity is nil/undefined.
                 // We should only attempt smart interaction if we actually refocused on something new.
                 await attemptSmartInteraction()
            }
        } catch {
            await handleError(error)
        }
    }

    // State tracking for text selection
    private var lastSelectedRange: Range<Int>?
    private var lastValue: String?

    /// Handles accessibility events received from the system.
    ///
    /// - Parameter event: The `ElementEvent` containing the notification type and payload.
    private func handleEvent(_ event: ElementEvent) async {
        do {
            switch event.notification {
            
            // NEW: Text Selection Handler
            case .textSelectionDidUpdate:
                // Only care if this is the focused element
                guard focus?.entity.element == event.subject else { break }
                
                // Get new state
                guard let newRange = try? await event.subject.getAttribute(.selectedTextRange) as? Range<Int>,
                      let value = try? await event.subject.getAttribute(.value) as? String else {
                    break // use break instead of return to close switch
                }
                
                // Compare with previous to decide what to speak
                if let oldRange = lastSelectedRange, let oldValue = lastValue, value == oldValue {
                    await handleSelectionChange(from: oldRange, to: newRange, in: value)
                } else {
                    // Context switch or value change
                    if newRange.isEmpty {
                         // Read char at cursor
                         await speakCharacterAt(index: newRange.lowerBound, in: value)
                    } else {
                         if let selectedText = try? await event.subject.getAttribute(.selectedText) as? String {
                             await Output.shared.announce("Selected: \(selectedText)")
                         }
                    }
                }
                
                // Update State
                lastSelectedRange = newRange
                lastValue = value
            case .applicationDidAnnounce:
                if let announcement = event.payload?[.announcement] as? String {
                    await Output.shared.announce(announcement)
                }
            case .elementDidAppear:
                guard focus == nil else {
                    try await observer?.unsubscribe(from: .elementDidAppear)
                    break
                }
                await refocus(processIdentifier: processIdentifier)
                if self.focus != nil {
                    try await observer?.unsubscribe(from: .elementDidAppear)
                }
            case .elementDidDisappear:
                guard event.subject == focus?.entity.element else {
                    break
                }
                let entity = try await AccessEntity(for: event.subject)
                guard let isFocusableAncestor = try await focus?.entity.isInFocusGroup(of: entity), !isFocusableAncestor else {
                    break
                }
                focus = nil
                await refocus(processIdentifier: self.processIdentifier)
            case .elementDidGetFocus:
                guard event.subject != focus?.entity.element else {
                    break
                }
                let newFocus = try await AccessFocus(on: event.subject)
                guard let oldFocus = focus, try await !oldFocus.entity.isInFocusGroup(of: newFocus.entity) else {
                    break
                }
                self.focus = newFocus
                await readFocus()
            
            case .windowDidAppear:
                let window = event.subject
                
                // 1. Intelligent Auto Focus
                if intelligentAutoFocus {
                    // Try to find content
                    if let windowEntity = try? await AccessEntity(for: window),
                       let target = await AutoFocus.findBestTarget(in: windowEntity) {
                        let newFocus = try await AccessFocus(on: target)
                        self.focus = newFocus
                         // Force keyboard focus to the content
                        try? await target.setKeyboardFocus()
                        
                        // Read it
                        var content = [OutputSemantic.window("New Window")] 
                        if let title = try? await window.getAttribute(.title) as? String {
                            content = [OutputSemantic.window(title)]
                        }
                        content.append(contentsOf: try await newFocus.reader.read())
                        await Output.shared.convey(content)
                        return // Skip dialog logic if we focused content? 
                        // Or maybe dialog logic is still relevant for alerts? 
                    }
                }
                
                // 2. Dialog Logic (Existing)
                guard autoSpeakDialogs else { break }
                if let role = try? await window.getAttribute(.role) as? ElementRole,
                   (role == .sheet || role == .drawer) {
                     var content = [OutputSemantic.window("Dialog")] 
                     if let title = try? await window.getAttribute(.title) as? String {
                         content = [OutputSemantic.window(title)]
                     }
                     await Output.shared.convey(content)
                }
                
            case .valueDidUpdate:
                if progressFeedback != 0 {
                    let role = try? await event.subject.getAttribute(.role) as? ElementRole
                    if role == .progressIndicator {
                         if let val = try? await event.subject.getAttribute(.value) as? Double {
                              if progressFeedback == 2 { // Speak
                                  await Output.shared.announce("\(Int(val)) percent")
                              } else { // Tone
                                   await SoundManager.shared.play(.beep)
                              }
                         }
                    }
                }
                
            case .rowCountDidUpdate:
                 if tableRowChangeFeedback != 0 {
                      let role = try? await event.subject.getAttribute(.role) as? ElementRole
                      if role == .table || role == .list {
                          if let rows = try? await event.subject.getAttribute(.rows) as? [Any] {
                               let rowCount = rows.count
                               if tableRowChangeFeedback == 1 {
                                   await Output.shared.announce("\(rowCount) rows")
                               } else {
                                   await SoundManager.shared.play(.texture)
                               }
                          }
                      }
                 }
                 
            case .loadComplete:
                // Handle Web Page Load
                if webLoadFeedback == 2 { await SoundManager.shared.play(.success) }
                else if webLoadFeedback == 1 { 
                    // Progress completion? Already done?
                    await Output.shared.announce("Loaded") 
                }
                
                // Summary?
                if speakWebSummary {
                   await Output.shared.announce("Page Summary: Implement logic")
                }
                
                // Auto Read?
                if autoReadWebPage {
                    // Start reading from top
                    // await readEntireWindow() // Need Access internal read all
                    await Output.shared.announce("Auto-Reading page...")
                }
                
            default:
                break 
            }
        } catch {
            await handleError(error)
        }
    }

    /// Dumps the accessibility hierarchy to a property list file.
    ///
    /// This is a debugging tool allowing the user to save the current element tree state.
    ///
    /// - Parameter element: The root element of the hierarchy to dump.
    @MainActor private func dumpElement(_ element: Element) async {
        do {
            guard let label = try await application?.getAttribute(.title) as? String, let dump = try await element.dump() else {
                let content = [OutputSemantic.noFocus]
                Output.shared.convey(content)
                return
            }
            let data = try PropertyListSerialization.data(fromPropertyList: dump, format: .binary, options: .zero)
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.message = "Choose a location to dump the selected accessibility elements."
            savePanel.nameFieldLabel = "Accessibility Dump Property List"
            savePanel.nameFieldStringValue = "\(label) Dump.plist"
            savePanel.title = "Save \(label) dump property list"
            let response = await savePanel.begin()
            if response == .OK, let url = savePanel.url {
                try data.write(to: url)
            }
        } catch {
            await handleError(error)
        }
    }

    /// Retrieves a list of currently running applications with a regular activation policy.
    ///
    /// - Returns: An array of tuples containing the application name and PID.
    nonisolated public func getApplications() -> [(name: String, processIdentifier: pid_t)] {
        return NSWorkspace.shared.runningApplications.filter({$0.activationPolicy == .regular}).map({($0.localizedName ?? "Unknown", $0.processIdentifier)})
    }

    /// Retrieves a list of windows for the active application.
    ///
    /// - Returns: An array of tuples containing the window title and its element.
    public func getWindows() async -> [(title: String, element: Element)] {
        guard let application = application else { return [] }
        do {
            guard let windows = try await application.getAttribute(.windows) as? [Element] else { return [] }
            var results = [(title: String, element: Element)]()
            for window in windows {
                 if let title = try await window.getAttribute(.title) as? String {
                     results.append((title.isEmpty ? "Untitled" : title, window))
                 }
            }
            return results
        } catch {
            return []
        }
    }
    
    /// Switches focus to a specific window element.
    public func focusWindow(_ window: Element) async {
        do {
            try await window.setAttribute(.isMain, value: true) // Make main window
            // Then find focus inside
             try await window.setAttribute(.isFocused, value: true) 
        } catch {
            await handleError(error)
        }
    }
    
    /// Cycles focus to the next window in the application's window list.
    public func focusNextWindow() async {
        await cycleWindow(forward: true)
    }
    
    /// Cycles focus to the previous window.
    public func focusPreviousWindow() async {
        await cycleWindow(forward: false)
    }
    
    private func cycleWindow(forward: Bool) async {
        guard let app = application else { return }
        
        do {
            // 1. Get all windows
            guard let windows = try await app.getAttribute(.windows) as? [Element], !windows.isEmpty else {
                await Output.shared.announce("No windows")
                return
            }
            
            // 2. Identify current focused window
            let current = try? await app.getAttribute(.focusedWindow) as? Element
            
            // 3. Find index
            let index = windows.firstIndex(where: { $0 == current }) ?? (forward ? -1 : windows.count)
            
            // 4. Calculate next index (wrapping)
            let nextIndex: Int
            if forward {
                nextIndex = (index + 1) % windows.count
            } else {
                nextIndex = (index - 1 + windows.count) % windows.count
            }
            
            let targetWindow = windows[nextIndex]
            
            // 5. Raise and Focus
            try? await targetWindow.performAction("AXRaise")
            try await targetWindow.setAttribute(.isMain, value: true)
            
            // 6. Attempt to focus content inside the window
            if let entity = try? await AccessEntity(for: targetWindow) {
                // Use AutoFocus logic to land on content, not just the window frame
                if let content = await AutoFocus.findBestTarget(in: entity) {
                    let focus = try await AccessFocus(on: content)
                    self.focus = focus
                    try? await content.setKeyboardFocus()
                    
                    // Announce Window Title + Content
                    var output = [OutputSemantic]()
                    if let title = try? await targetWindow.getAttribute(.title) as? String {
                        output.append(.window(title))
                    }
                    output.append(contentsOf: try await focus.reader.read())
                    await Output.shared.convey(output)
                    return
                }
            }
            
            // Fallback if no content found
            await refocus(processIdentifier: processIdentifier)
            
        } catch {
            await Output.shared.announce("Cannot switch window")
        }
    }
    
    /// Switches to an application by PID.
    nonisolated public func focusApplication(processIdentifier: pid_t) {
        if let app = NSRunningApplication(processIdentifier: processIdentifier) {
            app.activate()
        }
    }

    /// Attempts to automatically interact with the focused element.
    ///
    /// Uses heuristics to determine if the currently focused element warrants further interaction.
    ///
    /// This method is called after navigation to automatically drill down into single-child containers
    /// or other "interesting" elements, reducing manual navigation steps.
    public func attemptSmartInteraction() async {
        guard let currentFocusEntity = focus?.entity else { return }
        
        // Detach from the immediate navigation flow to avoid blocking UI/Speech
        Task {
            // Re-check validity inside task
            guard let children = try? await currentFocusEntity.element.getAttribute(.childElements) as? [Element] else { return }
            
            // Heuristic 1: Auto-enter single child
            if children.count == 1, let first = children.first, let firstEntity = try? await AccessEntity(for: first) {
                 // Check interesting roles logic (simplified)
                 if let role = try? await firstEntity.element.getAttribute(.role) as? ElementRole {
                     if role == .staticText || role == .image {
                         // Pass
                     }
                 }
                 await self.focusFirstChild()
            }
        }
    }
    
    /// Moves the mouse cursor to the center of the currently focused element.
    ///
    /// - Parameter click: If `true`, performs a left click after moving.
    public func moveMouseToFocus(click: Bool = false) async {
        guard let focus = focus else { return }
        do {
             // Need position and size
             guard let position = try await focus.entity.element.getAttribute(.position) as? CGPoint,
                   let size = try await focus.entity.element.getAttribute(.size) as? CGSize else {
                 return
             }
             let center = CGPoint(x: position.x + size.width / 2, y: position.y + size.height / 2)
             
             let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: center, mouseButton: .left)
             move?.post(tap: .cghidEventTap)
             
             if click {
                 let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left)
                 let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left)
                 down?.post(tap: .cghidEventTap)
                 up?.post(tap: .cghidEventTap)
             }
        } catch {
             // Ignore
        }
    }

    /// Handles errors arising from accessibility API interactions.
    ///
    /// - Parameter error: The error to handle, expected to be of type `ElementError`.
    private func handleError(_ error: any Error) async {
        guard let error = error as? ElementError else {
            fatalError("Unexpected error \(error)")
        }
        switch error {
        case .apiDisabled:
            let content = [OutputSemantic.apiDisabled]
            await Output.shared.convey(content)
        case .invalidElement:
            await refocus(processIdentifier: processIdentifier)
        case .notImplemented:
            let content = [OutputSemantic.notAccessible]
            await Output.shared.convey(content)
        case .timeout:
            let content = [OutputSemantic.timeout]
            await Output.shared.convey(content)
        default:
            Self.logger.warning("Unexpected error \(error, privacy: .public)")
            return
        }
    }
    
    // MARK: - Web Support
    
    private var webAccess: AccessWeb?
    
    /// Indicates if the current focus is within a web content area.
    public var isWebActive: Bool { webAccess != nil }
    
    /// Checks if the current focus or its ancestors are part of a web area.
    /// If so, initializes the `AccessWeb` helper for advanced web navigation.
    private func checkForWebArea() async {
        guard let focus = focus else { return }
        do {
            // Check if current element or ancestor is webArea
            if try await AccessEntity.hasWebAncestor(element: focus.entity.element) {
                // Find the web area root
                var current = focus.entity.element
                while true {
                    if let role = try? await current.getAttribute(.role) as? ElementRole, role == .webArea {
                        // Found it. Initialize AccessWeb if needed.
                        // Optimization: Check if we already have it for this root?
                        // For now, simple re-init.
                        webAccess = AccessWeb(root: current)
                        break
                    }
                    guard let parent = try? await current.getAttribute(.parentElement) as? Element else { break }
                    current = parent
                }
                
                // Auto-enable Browse Mode? 
                // Let VoshAgent handle that based on events or this state.
                // But we can convey it.
                await Output.shared.announce("Web Content")
            } else {
                webAccess = nil
            }
        } catch {
            webAccess = nil
        }
    }
    

    // MARK: - Reading & Review
    
    /// The current character index within the review content string.
    private var reviewIndex: String.Index?
    
    /// The current textual content being reviewed.
    private var reviewContent: String?
    
    /// Prepares the review cursor state for the current focus.
    ///
    /// This method fetches the content (value, title, or description) or math equation
    /// from the focused element and initializes the `reviewIndex`.
    private func prepareReview() async {
        guard let focus = focus else { return }
        
            let role = try? await focus.entity.element.getAttribute(.role) as? ElementRole
            if role == .math {
                let math = AccessMath(root: focus.entity.element)
                reviewContent = await math.getEquation()
                reviewIndex = await getReviewIndex(for: reviewContent ?? "")
                return
            }
        
        guard let content = await getReviewContent() else {
             reviewContent = nil
             reviewIndex = nil
             return
        }
        
        // If content changed, reset or try to map index?
        // Simple approach: if content string is different, reset to start or selection.
        if content != reviewContent {
            reviewContent = content
            reviewIndex = await getReviewIndex(for: content)
        }
    }

    /// Moves the review cursor by a specified textual unit.
    ///
    /// - Parameters:
    ///   - unit: The unit to move by (e.g., "Character", "Word", "Line").
    ///   - backwards: The direction of movement.
    public func moveReviewCursor(unit: String, backwards: Bool) async {
        await prepareReview()
        guard let content = reviewContent, let currentIndex = reviewIndex else { return }
        
        var newIndex = currentIndex
        var textToRead: String?
        
        switch unit {
        case "Character":
            if backwards {
                if currentIndex > content.startIndex {
                     newIndex = content.index(before: currentIndex)
                     textToRead = String(content[newIndex])
                }
            } else {
                if currentIndex < content.endIndex {
                     let next = content.index(after: currentIndex)
                     if next < content.endIndex {
                         newIndex = next
                         textToRead = String(content[newIndex])
                     }
                }
            }
        case "Word":
             if backwards {
                 // Move to start of current word if we are inside one?
                 // Or move to previous word start.
                 let range = getWordRange(in: content, at: currentIndex)
                 if range.lowerBound < currentIndex {
                     // We were in the middle/end of a word, move to its start
                     newIndex = range.lowerBound
                 } else {
                     // We were at start, find previous
                     var probe = currentIndex
                     // Skip preceding whitespace
                     while probe > content.startIndex {
                         let prev = content.index(before: probe)
                         if !content[prev].isWhitespace { break }
                         probe = prev
                     }
                     // Find start of that word
                     newIndex = getWordRange(in: content, at: probe).lowerBound
                     
                     // If we didn't move (e.g. at start), try to force back?
                     if newIndex == currentIndex && newIndex > content.startIndex {
                         newIndex = content.index(before: newIndex) // Force step back
                         newIndex = getWordRange(in: content, at: newIndex).lowerBound
                     }
                 }
                 let wordRange = getWordRange(in: content, at: newIndex)
                 textToRead = String(content[wordRange])
             } else {
                 // Move to next word start
                 let currentWordRange = getWordRange(in: content, at: currentIndex)
                 var probe = currentWordRange.upperBound
                 // Skip delimiter whitespace
                 while probe < content.endIndex {
                     if !content[probe].isWhitespace { break }
                     probe = content.index(after: probe)
                 }
                 newIndex = probe
                 
                 if newIndex < content.endIndex {
                    let wordRange = getWordRange(in: content, at: newIndex)
                    textToRead = String(content[wordRange])
                 }
             }
        case "Line":
             // Simple Line Logic based on newlines
             if backwards {
                 let lineRange = content.lineRange(for: currentIndex..<currentIndex)
                 if lineRange.lowerBound < currentIndex {
                     // Move to start of current line
                     newIndex = lineRange.lowerBound
                 } else {
                     // Move to previous line
                     if currentIndex > content.startIndex {
                         let prev = content.index(before: currentIndex)
                         newIndex = content.lineRange(for: prev..<prev).lowerBound
                     }
                 }
                 let newRange = content.lineRange(for: newIndex..<newIndex)
                 textToRead = String(content[newRange]).trimmingCharacters(in: .newlines)
             } else {
                 let lineRange = content.lineRange(for: currentIndex..<currentIndex)
                 if lineRange.upperBound < content.endIndex {
                     newIndex = lineRange.upperBound
                     let newRange = content.lineRange(for: newIndex..<newIndex)
                     textToRead = String(content[newRange]).trimmingCharacters(in: .newlines)
                 }
             }
        default: break
        }
        
        if let text = textToRead {
            self.reviewIndex = newIndex
            if unit == "Character" {
                 // Phonetic?
                 await Output.shared.announce(text)
            } else {
                 await Output.shared.announce(text)
            }
        } else {
            // Boundary
             await Output.shared.convey([OutputSemantic.boundary])
        }
    }

    /// Reads the current line based on the internal review cursor.
    ///
    /// - Parameter spell: If `true`, spells out the text characters instead of speaking normally.
    public func readCurrentLine(spell: Bool = false) async {
        await prepareReview()
        guard let content = reviewContent, let index = reviewIndex else { return }
        
        let range = content.lineRange(for: index..<index)
        let substring = content[range]
        let text = String(substring).trimmingCharacters(in: .newlines)
        
        if spell {
            await spellText(text)
        } else {
            await Output.shared.announce(text)
        }
    }
    
    /// Reads the current word based on the internal review cursor.
    ///
    /// - Parameter spell: If `true`, spells out the word characters.
    public func readCurrentWord(spell: Bool = false) async {
        await prepareReview()
        guard let content = reviewContent, let index = reviewIndex else { return }
        
        // Find word range
        let range = getWordRange(in: content, at: index)
        let text = String(content[range])
        
        if spell {
             await spellText(text)
        } else {
             await Output.shared.announce(text)
        }
    }
    
    /// Reads the current character based on the internal review cursor.
    ///
    /// - Parameter phonetic: If `true`, speaks the phonetic representation (e.g., "Alpha" for "A").
    public func readCurrentCharacter(phonetic: Bool = false) async {
        await prepareReview()
        guard let content = reviewContent, let index = reviewIndex else { return }
        
        if index < content.endIndex {
            let char = content[index]
            if phonetic {
                await Output.shared.announce(getPhonetic(for: char))
            } else {
                await Output.shared.announce(String(char))
            }
        }
    }
    
    private func spellText(_ text: String) async {
        for char in text {
            await Output.shared.announce(String(char))
            try? await Task.sleep(nanoseconds: 100_000_000) // Slight pause
        }
    }
    
    private func getPhonetic(for char: Character) -> String {
        let upper = char.uppercased()
        switch upper {
        case "A": return "Alpha"
        case "B": return "Bravo"
        case "C": return "Charlie"
        case "D": return "Delta"
        case "E": return "Echo"
        case "F": return "Foxtrot"
        case "G": return "Golf"
        case "H": return "Hotel"
        case "I": return "India"
        case "J": return "Juliet"
        case "K": return "Kilo"
        case "L": return "Lima"
        case "M": return "Mike"
        case "N": return "November"
        case "O": return "Oscar"
        case "P": return "Papa"
        case "Q": return "Quebec"
        case "R": return "Romeo"
        case "S": return "Sierra"
        case "T": return "Tango"
        case "U": return "Uniform"
        case "V": return "Victor"
        case "W": return "Whiskey"
        case "X": return "X-ray"
        case "Y": return "Yankee"
        case "Z": return "Zulu"
        case "0": return "Zero"
        case "1": return "One"
        case "2": return "Two"
        case "3": return "Three"
        case "4": return "Four"
        case "5": return "Five"
        case "6": return "Six"
        case "7": return "Seven"
        case "8": return "Eight"
        case "9": return "Nine"
        default: return String(char)
        }
    }
    
    private func getReviewContent() async -> String? {
        guard let focus = focus else { return nil }
        // Attempt to get Value, then Title, then Description
        do {
            if let value = try await focus.entity.element.getAttribute(.value) as? String { return value }
            if let title = try await focus.entity.element.getAttribute(.title) as? String { return title }
            if let desc = try await focus.entity.element.getAttribute(.description) as? String { return desc }
        } catch {}
        return nil
    }
    
    private func getReviewIndex(for content: String) async -> String.Index {
        guard let focus = focus else { return content.startIndex }
        do {
            if let selection = try await focus.entity.element.getAttribute(.selectedTextRange) as? Range<Int> {
                // Correct approach using UTF16 view
                let utf16 = content.utf16
                let startOffset = selection.lowerBound
                
                if let utf16Index = utf16.index(utf16.startIndex, offsetBy: startOffset, limitedBy: utf16.endIndex),
                   let stringIndex = String.Index(utf16Index, within: content) {
                    return stringIndex
                }
            }
        } catch {}
        return content.startIndex
    }
    
    private func getWordRange(in text: String, at index: String.Index) -> Range<String.Index> {
        // Simple word detection
        if text.isEmpty { return text.startIndex..<text.endIndex }
        guard index < text.endIndex else { return text.endIndex..<text.endIndex }
        
        var start = index
        var end = index
        
        // Expand start
        while start > text.startIndex {
            let prev = text.index(before: start)
            if text[prev].isWhitespace { break }
            start = prev
        }
        
        // Expand end
        while end < text.endIndex {
            if text[end].isWhitespace { break }
            end = text.index(after: end)
        }
        
        return start..<end
    }
    // MARK: - Browse Mode
    
    public func browseNext() async {
        guard let webAccess = webAccess else { return }
        if let element = await webAccess.next() {
             await focusBrowseElement(element)
        }
    }
    
    public func browsePrevious() async {
        guard let webAccess = webAccess else { return }
        if let element = await webAccess.previous() {
             await focusBrowseElement(element)
        }
    }
    
    public func browseNextElement(role: String) async {
        guard let webAccess = webAccess else { return }
        
        var targetElement: Element? = nil
        
        if role == "EditField" {
            targetElement = await webAccess.nextElement { el in
                 guard let r = try? await el.getAttribute(.role) as? ElementRole else { return false }
                 return r == .textField || r == .textArea
            }
        } else if role == "Blockquote" {
            targetElement = await webAccess.nextElement { el in
                 guard let r = try? await el.getAttribute(.role) as? ElementRole else { return false }
                 if r == .group {
                     let desc = (try? await el.getAttribute(.description) as? String) ?? ""
                     return desc.localizedCaseInsensitiveContains("blockquote")
                 }
                 return false
            }
        } else {
             let elementRole: ElementRole? = switch role {
                case "Heading": .heading
                case "Link": .link
                case "Button": .button
                default: nil
             }
             if let r = elementRole {
                 targetElement = await webAccess.nextElement(role: r)
             }
        }
        
        if let element = targetElement {
            await focusBrowseElement(element)
        }
    }
    
    public func browsePreviousElement(role: String) async {
        guard let webAccess = webAccess else { return }
        
        var targetElement: Element? = nil
        
        if role == "EditField" {
            targetElement = await webAccess.previousElement { el in
                 guard let r = try? await el.getAttribute(.role) as? ElementRole else { return false }
                 return r == .textField || r == .textArea
            }
        } else if role == "Blockquote" {
            targetElement = await webAccess.previousElement { el in
                 guard let r = try? await el.getAttribute(.role) as? ElementRole else { return false }
                 if r == .group {
                     let desc = (try? await el.getAttribute(.description) as? String) ?? ""
                     return desc.localizedCaseInsensitiveContains("blockquote")
                 }
                 return false
            }
        } else {
             let elementRole: ElementRole? = switch role {
                case "Heading": .heading
                case "Link": .link
                case "Button": .button
                default: nil
             }
             if let r = elementRole {
                 targetElement = await webAccess.previousElement(role: r)
             }
        }
        
        if let element = targetElement {
            await focusBrowseElement(element)
        }
    }
    
    public func findAllBrowseElements(role: String) async -> [(title: String, element: Element)] {
        guard let webAccess = webAccess else { return [] }
        // Map string to role
        let elementRole: ElementRole? = switch role {
            case "Heading": .heading
            case "Link": .link
            case "Button": .button
            default: nil
        }
        guard let r = elementRole else { return [] }
        
        let elements = await webAccess.findAll(role: r)
        var results: [(title: String, element: Element)] = []
        for element in elements {
             // Get title or description
             if let title = try? await element.getAttribute(.title) as? String, !title.isEmpty {
                 results.append((title, element))
             } else if let desc = try? await element.getAttribute(.description) as? String, !desc.isEmpty {
                 results.append((desc, element))
             } else {
                 results.append(("\(role)", element))
             }
        }
        return results
    }
    
    public func findBrowseElement(text: String, backwards: Bool = false) async {
        guard let webAccess = webAccess else { return }
        if let element = await webAccess.find(text: text, backwards: backwards) {
            await focusBrowseElement(element)
        } else {
            await Output.shared.announce("Not found")
        }
    }
    
    public func focusBrowseElement(_ element: Element) async {
        do {
            let focus = try await AccessFocus(on: element)
            self.focus = focus
            // Try setting keyboard focus too?
            try? await element.setAttribute(.isFocused, value: true) 
            // Read
            await readFocus()
        } catch {
            await handleError(error)
        }
    }
    
    /// Recursively reads the entire window content (BFS).
    public func readAllRecursively() async {
        guard let window = try? await application?.getAttribute(.focusedWindow) as? Element else { 
            await Output.shared.announce("No Window")
            return 
        }
        
        // Simple BFS
        var queue = [window]
        while !queue.isEmpty {
            if Task.isCancelled { break }
            let element = queue.removeFirst()
            
            // Read
            if let role = try? await element.getAttribute(.role) as? ElementRole {
                // Filter boring roles
                if role != .group && role != .window && role != .splitter {
                     // Read content
                     if let reader = try? await AccessReader(for: element) {
                         let content = try? await reader.read()
                         if let c = content, !c.isEmpty {
                             await Output.shared.convey(c)
                         }
                     }
                }
            }
            
            // Children
            if let children = try? await element.getAttribute(.childElements) as? [Element] {
                queue.append(contentsOf: children)
            }
        }
    }
    
    // MARK: - Helpers for VoshAgent (Avoiding Element import)
    
    public func getFocusedWindowTitle() async -> String? {
        guard let app = application else { return nil }
        guard let window = try? await app.getAttribute(.focusedWindow) as? Element else { return nil }
        return try? await window.getAttribute(.title) as? String
    }

    public func performActionOnFocus(_ action: String) async -> Bool {
        guard let focus = focus else { return false }
        return (try? await focus.entity.element.performAction(action)) != nil
    }

    public func raiseWindow(_ element: Element) async {
        try? await element.performAction("AXRaise")
    }

    public func readAllWeb() async {
        guard let web = webAccess else { return }
        for await text in await web.readFromCursor() {
            await Output.shared.announce(text)
        }
    }

    // MARK: - Review Cursor Navigation
    
    /// Moves the independent review cursor to the next or previous element in the hierarchy.
    ///
    /// This allows the user to explore the interface without changing the actual system keyboard focus.
    ///
    /// - Parameter backwards: Direction of navigation.
    public func moveReviewFocusNext(backwards: Bool = false) async {
        guard let current = reviewFocus else {
            // init from focus
            if let f = focus {
                reviewFocus = f
                await conveyReviewFocus()
            } else {
                await Output.shared.announce("No Focus to Review")
            }
            return
        }
        
        do {
            guard let parent = try await current.entity.getParent() else {
                 await Output.shared.announce("No Parent")
                 return
            }
            let children = (try? await parent.element.getAttribute(.childElements) as? [Element]) ?? []
            
            let currentElement = current.entity.element
            
            // Find index using description/role matching if simple equality fails, 
            // but usually Element instances from same fetch might match or we need IsEqual logic.
            // For MVP assuming identity or sequential scan match.
            
            var index: Int?
            for (i, child) in children.enumerated() {
                let r = (try? await child.getAttribute(.role) as? ElementRole)
                let d = (try? await child.getAttribute(.description) as? String)
                let currentR = (try? await currentElement.getAttribute(.role) as? ElementRole)
                let currentD = (try? await currentElement.getAttribute(.description) as? String)
                
                if r == currentR && d == currentD {
                    // Primitive check, works for many cases
                    index = i
                    break
                }
            }
            
            if let idx = index {
                let nextIndex = backwards ? idx - 1 : idx + 1
                if children.indices.contains(nextIndex) {
                    let nextElem = children[nextIndex]
                    let entity = try await AccessEntity(for: nextElem)
                    let newFocus = try await AccessFocus(on: entity)
                    self.reviewFocus = newFocus
                    await conveyReviewFocus()
                    
                    if focusFollowsReview {
                         if let r = reviewFocus {
                             try? await r.entity.setKeyboardFocus()
                             self.focus = r
                         }
                    }
                } else {
                    await Output.shared.convey([OutputSemantic.boundary])
                }
            } else {
                 await Output.shared.announce("Lost in hierarchy")
            }
            
        } catch {
             await Output.shared.announce("Nav Error")
        }
    }
    
    public func moveReviewFocusParent() async {
        guard let current = reviewFocus else { return }
        do {
            guard let parent = try await current.entity.getParent() else { return }
            let newFocus = try await AccessFocus(on: parent)
            self.reviewFocus = newFocus
            await conveyReviewFocus()
            
            if focusFollowsReview {
                 // AccessEntity has setKeyboardFocus. parent is AccessEntity.
                 try? await parent.setKeyboardFocus()
                 self.focus = newFocus
            }
        } catch {
             await Output.shared.convey([OutputSemantic.boundary])
        }
    }
    
    public func moveReviewFocusChild() async {
        guard let current = reviewFocus else { return }
        do {
            let children = (try? await current.entity.element.getAttribute(.childElements) as? [Element]) ?? []
            if let first = children.first {
                let entity = try await AccessEntity(for: first)
                let newFocus = try await AccessFocus(on: entity)
                self.reviewFocus = newFocus
                await conveyReviewFocus()
                
                if focusFollowsReview {
                     try? await entity.setKeyboardFocus()
                     self.focus = newFocus
                }
            } else {
                 await Output.shared.announce("No Children")
            }
        } catch {
             await Output.shared.announce("Error")
        }
    }
    
    private func conveyReviewFocus() async {
        guard let r = reviewFocus else { return }
        do {
            let content = try await r.reader.read()
            await Output.shared.convey(content)
        } catch {}
    }
    
    // MARK: - Mouse Routing
    
    public func moveReviewFocusToMouse() async {
        guard let event = CGEvent(source: nil) else { return }
        let point = event.location
        do {
            // Invert Y? AX usually uses top-left 0,0 (same as CG) for system wide queries?
            // "The coordinates are in the unified screen coordinate space."
            // CGEvent location is also unified screen space.
            // Should match.
            
            if let element = try await system.at(x: Float(point.x), y: Float(point.y)) {
                let focus = try await AccessFocus(on: await AccessEntity(for: element))
                self.reviewFocus = focus
                await conveyReviewFocus()
                await Output.shared.announce("Snapped")
            } else {
                 await Output.shared.announce("Nothing under mouse")
            }
        } catch {
             await Output.shared.announce("Error locating")
        }
    }
    
    public func moveMouseToReviewFocus() async {
        guard let focus = reviewFocus else { 
            await Output.shared.announce("No Review Focus")
            return 
        }
        do {
            if let position = try await focus.entity.element.getAttribute(.position) as? CGPoint,
               let size = try await focus.entity.element.getAttribute(.size) as? CGSize {
                
                let midX = position.x + (size.width / 2)
                let midY = position.y + (size.height / 2)
                
                let point = CGPoint(x: midX, y: midY)
                let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
                event?.post(tap: .cghidEventTap)
                // Also Warp?
                CGWarpMouseCursorPosition(point)
                
                await Output.shared.announce("Mouse Moved")
            }
        } catch {
             await Output.shared.announce("Cannot move mouse")
        }
    }
}
