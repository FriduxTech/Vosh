//
//  InputKeyCode.swift
//  Vosh
//
//  Created by Vosh Team.
//

/// Type-safe enumerations of standard Apple keyboard scancodes (User-independent).
///
/// These values correspond to the hardware key codes (Carbon `kVK_...` constants) used by
/// standard US ANSI keyboards. They are used to identify keys regardless of the active
/// software keyboard layout (e.g., QWERTY vs Dvorak), though the names here reflect QWERTY positions.
///
/// Use `Int64` raw values to match `CGEvent` field types.
public enum InputKeyCode: Int64 {
    
    // MARK: - Alphabet (A-Z)
    
    // Rows top-to-bottom, left-to-right (QWERTY approximation)
    
    case keyboardQ = 0xc
    case keyboardW = 0xd
    case keyboardE = 0xe
    case keyboardR = 0xf
    case keyboardT = 0x11
    case keyboardY = 0x10
    case keyboardU = 0x20
    case keyboardI = 0x22
    case keyboardO = 0x1f
    case keyboardP = 0x23
    
    case keyboardA = 0x0
    case keyboardS = 0x1
    case keyboardD = 0x2
    case keyboardF = 0x3
    case keyboardG = 0x5
    case keyboardH = 0x4
    case keyboardJ = 0x26
    case keyboardK = 0x28
    case keyboardL = 0x25
    
    case keyboardZ = 0x6
    case keyboardX = 0x7
    case keyboardC = 0x8
    case keyboardV = 0x9
    case keyboardB = 0xb
    case keyboardN = 0x2d
    case keyboardM = 0x2e

    // MARK: - Numbers (Row)
    
    case keyboard1AndExclamation = 0x12
    case keyboard2AndAt = 0x13
    case keyboard3AndHash = 0x14
    case keyboard4AndDollar = 0x15
    case keyboard5AndPercent = 0x17
    case keyboard6AndCaret = 0x16
    case keyboard7AndAmp = 0x1a
    case keyboard8AndStar = 0x1c
    case keyboard9AndLeftParen = 0x19
    case keyboard0AndRightParen = 0x1d

    // MARK: - Symbols & Punctuation
    
    case keyboardMinusAndUnderscore = 0x1b
    case keyboardEqualsAndPlus = 0x18
    case keyboardLeftBracketAndBrace = 0x21
    case keyboardRightBracketAndBrace = 0x1e
    case keyboardBackSlashAndVertical = 0x2a
    case keyboardSemiColonAndColon = 0x29
    case keyboardApostropheAndQuote = 0x27
    case keyboardGraveAccentAndTilde = 0x32
    case keyboardCommaAndLeftAngle = 0x2b
    case keyboardPeriodAndRightAngle = 0x2f
    case keyboardSlashAndQuestion = 0x2c

    // MARK: - Controls & Function Keys
    
    case keyboardReturn = 0x24
    case keyboardTab = 0x30
    case keyboardSpace = 0x31
    case keyboardBackDelete = 0x33 // Backspace
    case keyboardEscape = 0x35
    case keyboardCommand = 0x37
    case keyboardShift = 0x38
    case keyboardCapsLock = 0x39
    case keyboardOption = 0x3A

    // Function Row
    case keyboardF1 = 0x7a
    case keyboardF2 = 0x78
    case keyboardF3 = 0x63
    case keyboardF4 = 0x76
    case keyboardF5 = 0x60
    case keyboardF6 = 0x61
    case keyboardF7 = 0x62
    case keyboardF8 = 0x64
    case keyboardF9 = 0x65
    case keyboardF10 = 0x6d
    case keyboardF11 = 0x67
    case keyboardF12 = 0x6f
    
    case keyboardF13 = 0x69
    case keyboardF14 = 0x6b
    case keyboardF15 = 0x71
    case keyboardF16 = 0x6a
    case keyboardF17 = 0x40
    case keyboardF18 = 0x4f
    case keyboardF19 = 0x50
    case keyboardF20 = 0x5a

    // MARK: - Navigation & Editing
    
    /// The "Forward Delete" key (fn+delete).
    case keyboardDelete = 0x75
    case keyboardHome = 0x73
    case keyboardEnd = 0x77
    case keyboardPageUp = 0x74
    case keyboardPageDown = 0x79
    case keyboardLeftArrow = 0x7b
    case keyboardRightArrow = 0x7c
    case keyboardDownArrow = 0x7d
    case keyboardUpArrow = 0x7e
    case keyboardHelp = 0x72 // Insert/Help key

    // MARK: - Keypad
    
    case keypadNumLock = 0x47
    case keypadDivide = 0x4b
    case keypadMultiply = 0x43
    case keypadSubtract = 0x4e
    case keypadAdd = 0x45
    case keypadEnter = 0x4c
    case keypadDecimalAndDelete = 0x41
    case keypadEquals = 0x51
    
    case keypad0 = 0x52
    case keypad1AndEnd = 0x53
    case keypad2AndDownArrow = 0x54
    case keypad3AndPageDown = 0x55
    case keypad4AndLeftArrow = 0x56
    case keypad5 = 0x57
    case keypad6AndRightArrow = 0x58
    case keypad7AndHome = 0x59
    case keypad8AndUpArrow = 0x5b
    case keypad9AndPageUp = 0x5c

    // MARK: - Media
    
    case keyboardVolumeUp = 0x48
    case keyboardVolumeDown = 0x49
    case keyboardVolumeMute = 0x4a
}
