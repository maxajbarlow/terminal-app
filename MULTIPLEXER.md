# Terminal Multiplexer Guide

The Terminal App now includes a powerful terminal multiplexer, similar to `tmux`, that allows you to manage multiple terminal sessions, windows, and panes efficiently.

## Quick Start

1. **Create a Multiplexer Tab**: Click the `+` button in the tab bar and select "New Multiplexer"
2. **Split Panes**: Use `⌘D` (horizontal) or `⌘⇧D` (vertical) to split the current pane
3. **Create Windows**: Use `⌘T` to create a new window within the session
4. **Navigate**: Use `⌘O` to cycle through panes, `⌘]` and `⌘[` for windows

## Key Features

### Sessions
- **Multiple Sessions**: Create and manage multiple independent terminal sessions
- **Session Persistence**: Sessions maintain state even when detached
- **Session Switching**: Easily switch between different sessions

### Windows
- **Multiple Windows per Session**: Each session can have multiple windows
- **Window Tabs**: Visual tab bar showing all windows in the current session
- **Window Management**: Create, switch, and close windows with keyboard shortcuts

### Panes
- **Flexible Splitting**: Split panes horizontally or vertically
- **Active Pane Indicator**: Clear visual feedback showing which pane is active
- **Pane Navigation**: Easy navigation between panes with keyboard shortcuts

### Layouts
- **Adaptive Layouts**: Automatically adjusts layout based on number of panes
- **Single Pane**: One terminal per window
- **Horizontal Split**: Side-by-side panes
- **Vertical Split**: Top/bottom panes  
- **Grid Layout**: 2x2 grid for 3-4 panes
- **Complex Layout**: Handles 5+ panes intelligently

## Keyboard Shortcuts

### Window Management
- `⌘T` - New window
- `⌘W` - Kill current window
- `⌘]` - Next window
- `⌘[` - Previous window

### Pane Management
- `⌘D` - Split pane horizontally
- `⌘⇧D` - Split pane vertically
- `⌘O` - Navigate to next pane
- `⌘⇧K` - Kill current pane

## tmux-Compatible Commands

You can use familiar tmux commands directly in any terminal pane:

### Session Commands
```bash
tmux new-session -s mysession    # Create named session
tmux detach-client              # Detach from current session
tmux list-sessions              # List all sessions
```

### Window Commands
```bash
tmux new-window -n mywindow     # Create named window
tmux next-window               # Switch to next window
tmux previous-window           # Switch to previous window
tmux kill-window              # Kill current window
```

### Pane Commands
```bash
tmux split-window             # Split vertically
tmux split-window -h          # Split horizontally
tmux select-pane -L           # Move to left pane
tmux select-pane -R           # Move to right pane
tmux select-pane -U           # Move to upper pane
tmux select-pane -D           # Move to lower pane
tmux kill-pane               # Kill current pane
```

## User Interface

### Status Bar
- **Session Indicator**: Shows current session name (clickable to switch sessions)
- **Window Tabs**: Shows all windows with pane count indicators
- **Control Buttons**: Quick access to new window, split horizontal, split vertical

### Session Manager
- **Session List**: View all active sessions
- **Session Creation**: Create new named sessions
- **Session Actions**: Attach to or kill sessions

### Pane Indicators
- **Active Pane Border**: Blue border around the currently active pane
- **Click to Focus**: Click any pane to make it active
- **Visual Separators**: Clear dividers between panes

## SSH and Mosh Integration

Each pane can connect to different servers:
- **Independent Connections**: Each pane can have its own SSH/Mosh connection
- **Mixed Connections**: Combine local shells with remote connections
- **Connection Persistence**: SSH/Mosh connections survive pane operations

## Advanced Usage

### Development Workflow
1. Create a session for your project: `tmux new-session -s myproject`
2. Split into panes for different tasks:
   - Main editor pane
   - Build/test pane  
   - Log monitoring pane
   - SSH to production server
3. Create additional windows for different services
4. Detach when switching tasks, reattach later

### System Administration
1. Create monitoring session: `tmux new-session -s monitoring`
2. Split into multiple panes for different servers
3. Use SSH connections to monitor different machines
4. Keep session running in background

### Comparison with tmux

| Feature | Terminal Multiplexer | tmux |
|---------|---------------------|------|
| Sessions | ✅ Full support | ✅ Full support |
| Windows | ✅ Full support | ✅ Full support |
| Panes | ✅ Full support | ✅ Full support |
| Commands | ✅ Compatible subset | ✅ Full command set |
| Shortcuts | ✅ ⌘-based (macOS) | ✅ Ctrl-based |
| Interface | ✅ Native SwiftUI | ✅ Text-based |
| Integration | ✅ Built-in SSH/Mosh | ✅ External tools |

## Tips and Tricks

1. **Quick Setup**: Use the session manager to quickly create and organize sessions
2. **Keyboard Focus**: Learn the keyboard shortcuts for fast navigation
3. **Pane Sizing**: Panes automatically resize based on screen space
4. **Session Naming**: Use descriptive session names for easy identification
5. **Window Organization**: Group related tasks in separate windows
6. **Mixed Usage**: Combine multiplexer tabs with regular terminal tabs as needed

## Troubleshooting

### Common Issues
- **Pane Not Responding**: Click the pane to ensure it has focus
- **Keyboard Shortcuts Not Working**: Make sure the multiplexer tab is active
- **Session Not Found**: Check the session manager for available sessions

### Performance
- The multiplexer is optimized for multiple concurrent connections
- Each pane runs independently without affecting others
- Session state is efficiently managed in memory

This terminal multiplexer provides enterprise-grade terminal management with the convenience of native macOS integration!