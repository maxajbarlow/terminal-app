# 🔍 Debugging Guide: Escape Key False Positive

## Problem
Escape key still shows new command prompt without actually killing the process.

## Debugging Steps Added

### 1. **Key Event Logging**
- Added logging to `keyDown()` to see ALL key events
- Shows keyCode, characters, and modifiers
- Escape key (keyCode 53) now explicitly ignored

### 2. **Command Selector Logging** 
- Added logging to `doCommandBy()` to see ALL command selectors
- Will show what selector Escape key triggers (if any)

### 3. **Interrupt Source Tracking**
- Added logging to `handleInterrupt()` to see when it's called
- Added logging to `showNewPrompt()` to see when prompt appears
- Added specific logging for Ctrl+C detection

## How to Debug

### Step 1: Build and Run
Build the app with the new debugging code.

### Step 2: Run 'top' Command
1. Start the terminal app
2. Run `top` command
3. Let it run for a few seconds

### Step 3: Test Escape Key
1. Press **Escape key**
2. Watch the **Xcode console** output
3. Look for these messages:

Expected output:
```
🔍 keyDown: keyCode=53, chars='', modifiers=...
🚨 Escape key pressed - IGNORING (should not trigger interrupt)
```

### Step 4: Test Ctrl+C
1. Run `top` again
2. Press **Ctrl+C**  
3. Look for these messages:

Expected output:
```
🔍 keyDown: keyCode=..., chars='', modifiers=...
🎯 Ctrl+C detected in keyDown
🚨 handleInterrupt() called - isCommandRunning=true
```

OR:
```
🔍 doCommandBy: cancelOperation(_:)
🎯 Ctrl+C detected in doCommandBy (cancelOperation)
🚨 handleInterrupt() called - isCommandRunning=true
```

## What to Look For

### ✅ Good Scenario (Fixed)
- Escape key: Only shows "IGNORING" message, no handleInterrupt() call
- Ctrl+C: Shows proper interrupt handling

### ❌ Bad Scenario (Still Broken)  
- Escape key: Shows `handleInterrupt()` being called
- Or shows `showNewPrompt()` being called without interrupt
- Or shows unexpected command selector

## Potential Issues to Investigate

### Issue 1: NSTextView Direct Handling
If Escape triggers a different selector, check what `doCommandBy` receives.

### Issue 2: Parent Class Handling
The `super.keyDown()` call might still process Escape in unexpected ways.

### Issue 3: Other Interrupt Sources
There might be other code paths calling `showNewPrompt()` or `handleInterrupt()`.

## Next Steps Based on Output

### If Escape shows "IGNORING" but still triggers prompt:
- Look for other calls to `showNewPrompt()` in logs
- Check if `onCommandCompleted` is being called elsewhere

### If Escape shows different keyCode/selector:
- The key mapping might be different on your system
- Add the actual keyCode to the ignore list

### If no keyDown events show for Escape:
- The event might be handled at a different level
- Check parent view controllers or responder chain

## Console Commands to Help Debug

In Xcode console, you can also run:
```bash
# Check if top process is actually running
ps aux | grep top

# Check terminal process tree  
ps -ef | grep -E "top|Terminal"
```

Run these commands BEFORE and AFTER pressing Escape to see if the process actually dies.