# LoopyPro MIDI Control Reference

Condensed reference for controlling LoopyPro from external MIDI controllers (Midifighter Twister, webapp via iConnectivity AUDIO4c). Covers the binding model, all available actions, and the specific CC mapping used in the explorer-ps / MC6 Project setup.

---

## Current Setup (Explorer)

**Hardware path**: Webapp → WebMIDI → iConnectivity AUDIO4c USB1 → iPad (LoopyPro)

**Channel**: 16 (configurable, stored in localStorage)

**CC Mapping**:

| CC | Action | LoopyPro Identifier | Subject |
|----|--------|---------------------|---------|
| 20 | Record | Track Record/Stop | None (global) |
| 21 | Play/Stop | Track Play/Stop | Selected Track |
| 22 | Clear | Clear Track | Selected Track |
| 23 | Mute | Mute | Selected Track |
| 24 | Solo | Track Solo | Selected Track |
| 25 | Multiply (×2) | Multiply Track | Selected Track |
| 26 | Divide (÷2) | Divide Track | Selected Track |
| 27 | Previous (◄) | Track Select | Global (param: Previous) |
| 28 | Next (►) | Track Select | Global (param: Next) |
| 30–39 | Select loop 0–9 | Track Select | Position index |

**Track layout**: 5 color groups × 2 tracks = 10 tracks total. Colors: Orange, Yellow, Lime, Blue, Magenta. Each group has an A track and a B track.

**Message format**: Momentary CC — send value 127, wait 50ms, send value 0.

**Project generation**: `node music/MC6 Project/explorer/generate-lpproj.js` produces an `.lpproj` bundle with all bindings pre-configured. AirDrop to iPad.

---

## Binding Model

### Trigger → Binding → Action(s)

- **Trigger**: Any incoming MIDI message (CC, Note On/Off, Program Change)
- **Binding**: Maps a trigger to one or more chained actions
- **Profile**: Container for bindings. Can be **Project** (stored in `.lpproj`, can reference specific clips) or **Global** (available across all projects, should not reference specific clips)

### Gesture Differentiation

A single MIDI trigger can be split into three gestures:

| Gesture | Detection |
|---------|-----------|
| **Tap** | Single press/release |
| **Hold** | Sustained >500ms |
| **Double-Tap** | Two presses within 250ms |

Key parameters:
- **Defer Other Actions**: On Hold/Double-Tap bindings, prevents the Tap action from firing prematurely
- **Preempt Other Actions**: On Record/Play actions (default ON), fires on single tap even when double-tap is configured. Often needs disabling.

### Action Chaining Timing

| Timing | Meaning |
|--------|---------|
| **With Last** | Simultaneous with previous action |
| **After Last** | After previous action completes |
| **Next Trigger** | On next press of same trigger (multi-step button) |
| **Quantized** | At next clock-aligned moment |
| **Delay** | After specified time (supports seconds.ms in 2.0+) |

### MIDI Learn

1. Enter MIDI Learn mode (main menu)
2. Tap on-screen element to bind
3. Send MIDI message from controller
4. Binding is created in the chosen profile
5. Edit in Control Settings to add more actions, change timing, etc.

---

## Complete Action Catalogue

### Clip Actions

| Action | Description |
|--------|-------------|
| **Play/Stop** | Toggle playback. Option: "Record If Empty" |
| **Record** | Record/stop recording. Options: "If Clip Has Audio" → Overdub / Play If Stopped / Overdub If Playing. "After Recording" → Play / Stop / Overdub |
| **Solo** | Solo clip (mutes all others) |
| **Mute** | Mute/unmute |
| **Clear Clip** | Erase audio |
| **Adjust Parameter** | Continuous: Volume, Balance (pan), Pitch, Speed |
| **Adjust Playhead** | Scrub/jump playback position |
| **Multiply Length** | Double clip by repeating contents |
| **Divide Length** | Halve clip |
| **Reverse** | Toggle reverse playback |
| **Peel/Replace Layers** | Undo/redo overdub layers |
| **Select** | Mark as selected (white dot) |
| **Phase Align** | Align clip phase with master clock |
| **Cancel Count Ins/Outs** | Cancel pending operations |

### Color Group Actions

| Action | Description |
|--------|-------------|
| **Play/Stop** | All clips of a color |
| **Solo / Mixer Solo** | Solo a color group |
| **Mute** | Mute a color group |
| **Adjust Parameter** | Color group Volume, Balance |

### Clock Actions

| Action | Description |
|--------|-------------|
| **Toggle Clock Pause** | Play/pause master clock |
| **Tap Tempo** | Tap tempo input |
| **Adjust Tempo** | Continuous tempo control (jog) |
| **Adjust Beats Per Bar** | Change time signature numerator |
| **Set Master Length** | Change master cycle length (affects quantization) |
| **Toggle Metronome** | On/off |
| **Adjust Metronome Volume** | Continuous |
| **Reset Clock** | Reset tempo to unset |
| **Toggle MIDI Clock Sync** | Enable/disable MIDI clock |
| **Toggle Ableton Link** | Enable/disable Link sync |

### Effect Actions

| Action | Description |
|--------|-------------|
| **Enable/Disable Effect** | Toggle on/off |
| **Adjust Effect Parameter** | Continuous control of any AUv3 parameter |
| **Select Effect Preset** | Switch presets |

### Session Actions

| Action | Description |
|--------|-------------|
| **Undo / Redo** | Session-level undo/redo |
| **Adjust Master Volume** | Continuous |
| **Cancel Pending Actions** | Cancel all quantized actions |
| **Load Project** | Set list navigation |
| **Save Project** | Save |
| **Toggle Sequence** | Start/stop sequencer |
| **Toggle Mixer** | Show/hide mixer |

### Controller Actions

| Action | Description |
|--------|-------------|
| **Switch Controller Profile** | Change active profile via MIDI |
| **Trigger Widget** | Trigger on-screen widget (macro buttons) |
| **Switch Page** | Navigate canvas pages |
| **Send MIDI Message** | Send arbitrary MIDI to a destination |

### Follow Actions (Event-Driven)

Trigger automatically on state changes:
- Begin Record → action(s)
- Finish Initial Record → action(s)
- Play Clip → action(s)
- Stop Clip → action(s)
- Clear Clip → action(s)

Useful for context-sensitive behaviors (e.g., when a clip plays, stop others in same color).

---

## Targeting / Selection

### Direct

Bindings created via MIDI Learn on a specific clip target that clip directly.

### Selected Clip

The **Select** action marks a clip (white dot). Other actions targeting "Selected Clip" operate on it. **Select Next/Previous** cycle through clips.

### By Color

Actions can target "All clips of [color]", "All playing clips of [color]", etc.

### Play Groups

Clips in a play group can be configured as mutex (starting one stops others).

---

## Quantization

### Count-In (when recording starts)

| Mode | Behavior |
|------|----------|
| None | Immediate |
| Master | Next master cycle boundary |
| Loop | If empty: Master. If has audio: next loop cycle |
| Custom | User-defined interval |

### Count-Out (when recording stops)

Same modes as Count-In. "Auto Count Out" enables fixed-length recording.

### Settings Hierarchy

Project-wide → Color Level → Individual Clip (highest priority)

### MIDI Control

No direct "change quantization mode" action. Workarounds:
- Different bindings with different per-action quantization overrides
- **Set Master Length** changes what "Master" means
- **Adjust Beats Per Bar** changes time signature

---

## Clock

- Tempo set by: first recorded loop (auto-detection), tap tempo, manual entry, external sync
- **MIDI Clock**: LoopyPro sends AND receives. Enable "CLOCK INPUT" for your interface in Settings → MIDI
- **Ableton Link**: Alternative sync. Don't use both simultaneously.
- Master Cycle Length is the quantization interval. Adjustable via **Set Master Length** action.
- Default time signature: 4/4

---

## State Feedback

LoopyPro sends MIDI feedback to controllers on the **same channel and message type** as the learned trigger.

### What generates feedback

- Clip playing/stopped/muted/recording → button LED state
- Parameter values → encoder ring position
- Effect enabled/disabled → button LED state

### MFT-specific

- MFT System MIDI Channel must match the control channel
- Factory default system channel: 4
- Feedback must be enabled in Control Settings for the controller
- Disable feedback if strange loops occur

---

## One-Button Record/Play/Overdub Pattern

A common single-button workflow:

1. **Play/Stop** with "Record If Empty" ON, "After Recording" = Play
2. **Record** with "If Clip Has Audio" = Overdub, timing = "Next Trigger"

Press sequence: record → stop+play → overdub → stop overdub → ...

---

## LoopyPro 2.0 Additions (July 2025)

- MIDI Clips (record/edit/playback MIDI loops, piano roll)
- Polyphonic Clip Playback (trigger clips as pitched notes or slices via MIDI)
- Groove Quantization / Warp
- MIDI Parameter Automation on audio and MIDI loops
- Latency Compensation for MIDI controllers
- Absolute timing in actions (seconds.milliseconds)

---

## Built-In MFT Support

LoopyPro has native Midifighter Twister support:

### Automatic Binding Mode (when enabled)

- 4×4 knob grid maps to clips
- LED rings show playhead position
- Button press toggles play/stop
- Colors match track colors

Dial modes: Loop location (default), Volume, Pan, Custom CC

Button behaviors (configurable): None, Toggle Play, Toggle Record, Clear

### Manual Binding Mode

Disable automatic bindings → full manual control via MIDI Learn. Retain LED feedback.

### Configuration Notes

- Default MFT channel: 2, CC Hold mode, CC 0-15 for bank 1
- System MIDI channel must match for feedback (factory: channel 4)
- Connect in same USB port order each time (iOS can't distinguish identical controllers)
- Disable automatic bindings before adding custom bindings to avoid conflicts
