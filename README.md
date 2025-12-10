#VOSH

A project to develop a third-party screenreader for MacOS. Based on [VOSH](https://github.com/FriduxTech/Vosh) by João Santos.

João kickstarted this project in 2024, releasing his sourcodefor a basic screenreader implementation. This was no small undertaking. João's knowledge of Apple's largely undocumented APIs a third-party MacOS screenreader possible, but we have a long way to go.

Voiceover on MacOS is a buggy mess, with bugs dating back 15 years. For a company the with Apple's resources, who claims to care so deeply about accessibility, this is inexcusable. Some bugs do get fixed, occasionally, but there is no clear communication with the user community and the rapid MacOS release updates tend to break more than they fix.

Recent bugs in MacOS 26.1 inspired me to take a look at VOSH, and see if I could move the project forward. I don't claim to be a Swift expert. This code is very much experimental. The repo exists to allow others to contribute to the effort.

##Keyboard Shortcuts

Here is a list of the keyboard shortcuts currently defined in the Vosh codebase.

> **Note:** The **Vosh Modifier** is **Caps Lock** by default. You can also configure it to be **Control + Option** or **Insert** (Numpad 0) in the settings.
> Unless specified as "Browse Mode" or "Numpad", all shortcuts below require holding the **Vosh Modifier**.

### General & System
* **V**: Open Vosh Menu
* **Q**: Quit Vosh
* **S**: Toggle Speech (Mute)
* **Shift + S**: Toggle Screen Curtain
* **1**: Toggle Input Help Mode
* **Shift + Cmd + V**: Toggle Speech Viewer
* **,** (Comma): Focus Menu Bar
* **M**: Window Menu
* **W**: Announce Window Title
* **Shift + W**: List all Open Windows
* **A**: Announce Application Name
* **Shift + A**: List Running Applications
* **Shift + D**: Focus Dock

### Navigation
* **Right Arrow**: Next Item
* **Left Arrow**: Previous Item
* **Shift + Up Arrow**: Go to Parent (Out)
* **Shift + Down Arrow**: Go to First Child (In)
* **Up Arrow**: Rotor Up (Previous Value)
* **Down Arrow**: Rotor Down (Next Value)
* **U**: Next Rotor Option
* **Shift + U**: Previous Rotor Option

### Reading
* **B**: Read Entire Window
* **R**: Read from Cursor
* **T**: Read Time and Date
* **C**: Read Clipboard
* **Shift + C**: Copy Last Spoken Text to Clipboard
* **F**: Read Text Formatting/Attributes
* **Shift + ?**: Ask Vosh (AI Assistant)
* **Shift + K**: Announce Context ("Where am I?")
* **Ctrl + Left Arrow**: Previous Speech History
* **Ctrl + Right Arrow**: Next Speech History

#### Text Granularity
These commands support single and double press actions:
* **L**: Read Current Line (Single Press) / Spell Line (Double Press)
* **K**: Read Current Word (Single Press) / Spell Word (Double Press)
* **;** (Semicolon): Read Character (Single Press) / Phonetic Character (Double Press)

### Review Cursor (Object Navigation)
Allows you to explore the screen without moving the keyboard focus.
* **Shift + Right Arrow**: Review Next
* **Shift + Left Arrow**: Review Previous
* **Shift + Up Arrow**: Review Parent
* **Shift + Down Arrow**: Review Child
* **Shift + M**: Move Mouse to Review Cursor
* **Ctrl + M**: Move Review Cursor to Mouse
* **Shift + 6 (^)**: Toggle "Review follows Focus"
* **Shift + Space**: Toggle "Focus follows Review"

---

### Browse Mode (Single Letter Navigation)
These keys work **without** the Vosh Modifier when inside a Web Area or Document.
* **Space** (with Modifier): Toggle Browse Mode on/off manually

**Navigation Keys:**
* **H**: Next Heading
* **Shift + H**: Previous Heading
* **K**: Next Link
* **Shift + K**: Previous Link
* **E**: Next Edit Field
* **Shift + E**: Previous Edit Field
* **Q**: Next Blockquote
* **Shift + Q**: Previous Blockquote
* **F**: Find Text
* **Shift + F**: Find Next

**Lists:**
* **Shift + L**: List Links
* **Shift + H**: List Headings

---

### Numpad Commander
These keys work **without** the Vosh Modifier if "Numpad Commander" is enabled in settings.
* **Numpad 1**: Window Menu
* **Numpad 2**: Rotor Down
* **Numpad 3**: Context Menu (Right Click)
* **Numpad 4**: Previous Item
* **Numpad 5**: Activate (Click)
* **Numpad 6**: Next Item
* **Numpad 7**: Parent
* **Numpad 8**: Rotor Up
* **Numpad 9**: First Child
* **Numpad / (Divide)**: Settings
* **Numpad =**: Menu Bar
* **Numpad . (Decimal)**: Dock