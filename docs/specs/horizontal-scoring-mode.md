# Horizontal Scoring Mode - Specification

**Issue:** #62  
**Status:** Draft  
**Author:** MostronatorCoder[bot]  
**Created:** 2026-03-16

---

## 1. Overview

### 1.1 Purpose
Provide a landscape-oriented scoring interface that eliminates tab switching between fighters, allowing operators to score both fighters instantly during fast-paced BJJ matches.

### 1.2 Problem Statement
Current vertical mode requires:
1. Select fighter tab (Alice or Bob)
2. Press scoring button
3. Repeat for every action

This tab-switching wastes precious seconds when action alternates rapidly between fighters.

### 1.3 Solution
Horizontal landscape mode with **duplicated scoring controls** — one set for each fighter, visible simultaneously.

---

## 2. Layout Structure

### 2.1 Screen Division

```
┌────────────────────────────────────────────────┬────────┐
│                                                │        │
│           LEFT PANEL (SCORING)                 │ RIGHT  │
│              80% width                         │ PANEL  │
│                                                │ 20%    │
│                                                │        │
└────────────────────────────────────────────────┴────────┘
```

**Flex ratio:** `Expanded(flex: 4)` for left, `Expanded(flex: 1)` for right

### 2.2 Left Panel (Scoring)

**Layout:** Vertical split in half (Row with 2 equal Expanded children)

```
┌─────────────────────────────────────────────────┐
│  Fighter 1 Name                                 │
│  [+4] [+3] [+2]    [🫳 A] [✊ P]               │
│   ##   ##   ##       ##     ##                 │
│  [+][-][+][-][+][-] [+][-] [+][-]             │
├─────────────────────────────────────────────────┤
│  Fighter 2 Name                                 │
│  [+4] [+3] [+2]    [🫳 A] [✊ P]               │
│   ##   ##   ##       ##     ##                 │
│  [+][-][+][-][+][-] [+][-] [+][-]             │
└─────────────────────────────────────────────────┘
```

**Components per fighter section:**
- Fighter name (top, 14px bold)
- 3 scoring columns (+4, +3, +2)
- 1 advantage/penalty column (🫳 A, ✊ P)

**Each scoring column contains:**
- Badge at top (+4, +3, or +2)
- Count number (large, center)
- [+] and [-] buttons (below count)

**Advantage/Penalty column contains:**
- Emoji (🫳 or ✊)
- Count number
- [+] and [-] buttons (mini size)

### 2.3 Right Panel (Timer/Score)

**Background:** Solid black

**Layout:** Vertical column, centered

```
┌──────────┐
│  #abcd   │  ← Match ID badge (5 chars)
│          │
│    ##    │  ← Fighter 1 Score (colored bg)
│          │
│  [⏸][↩️] │  ← Pause + Undo buttons
│          │
│   3:45   │  ← Timer (large, monospace)
│          │
│    ##    │  ← Fighter 2 Score (colored bg)
│          │
└──────────┘
```

**Order from top to bottom:**
1. Match ID badge
2. Fighter 1 score (with colored background)
3. Control buttons (pause + undo, side by side)
4. Timer
5. Fighter 2 score (with colored background)

**NO back button** — exit by rotating device to portrait

---

## 3. Component Specifications

### 3.1 Modern Badge (+4, +3, +2)

**Style:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: colors.primary.withOpacity(0.12),
    borderRadius: BorderRadius.circular(6),
    border: Border.all(
      color: colors.primary.withOpacity(0.3),
      width: 1,
    ),
  ),
  child: Text(
    '+4',  // or '+3', '+2'
    style: TextStyle(
      color: colors.primary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
    ),
  ),
)
```

**Properties:**
- Rounded corners (6px radius)
- Subtle background (primary 12% opacity)
- Border (primary 30% opacity, 1px)
- No emojis on badges
- Letter spacing for readability

### 3.2 Count Display

**Style:**
```dart
Text(
  count.toString(),
  style: TextStyle(
    color: colors.onSurface,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
)
```

**Properties:**
- Bold weight
- 24px size (scoring columns)
- 14px size (A/P column)
- Surface color

### 3.3 Increment/Decrement Buttons

**Scoring columns (+4, +3, +2):**
```dart
SizedBox(
  width: 30,
  height: 30,
  child: IconButton(
    onPressed: onIncrement,
    padding: EdgeInsets.zero,
    iconSize: 16,
    icon: Icon(Icons.add),
    style: IconButton.styleFrom(
      backgroundColor: colors.primary.withOpacity(0.1),
      foregroundColor: colors.primary,
    ),
  ),
)
```

**Properties:**
- Size: 30×30 for scoring, 18×18 for A/P
- [+] button: primary color
- [-] button: error color
- Background: 10% opacity
- Zero padding

### 3.4 Advantage/Penalty Column

**Emoji only (no text labels):**
- Advantage: 🫳 (open hand)
- Penalty: ✊ (fist)

**Size:**
- Emoji: 14px
- Count: 14px bold
- Buttons: 18×18

**Layout:**
- Column width: 50px fixed
- Spacing between A and P: 2px

### 3.5 Match ID Badge

**Location:** Top of right panel, above Fighter 1 score

**Style:**
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.08),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    '#${match.id.substring(0, 5)}',
    style: TextStyle(
      color: Colors.white.withOpacity(0.6),
      fontSize: 10,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
  ),
)
```

**Properties:**
- Shows first 5 characters of match ID
- Format: `#abcd`
- Subtle badge style
- Translucent white

### 3.6 Fighter Score Display

**Location:** Right panel, above and below timer

**Style:**
```dart
Container(
  padding: EdgeInsets.symmetric(
    horizontal: scoreSize * 0.3,
    vertical: scoreSize * 0.15,
  ),
  decoration: BoxDecoration(
    color: f1Color,  // Fighter's color as background
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    '${match.f1Score}',
    style: TextStyle(
      color: f1Color.computeLuminance() > 0.5
          ? Colors.black  // Light background
          : Colors.white, // Dark background
      fontSize: scoreSize,
      fontWeight: FontWeight.bold,
    ),
  ),
)
```

**Properties:**
- Background: Fighter's color (f1_color or f2_color)
- Rounded corners: 8px
- Padding: Proportional to score size (30% horizontal, 15% vertical)
- Text color: Auto-contrast based on luminance
  - luminance > 0.5 → black text
  - luminance ≤ 0.5 → white text
- Font size: Adaptive (20% of panel height, clamped 36-100px)

### 3.7 Control Buttons (Pause + Undo)

**Layout:** Row with 2 buttons, centered

**Pause/Play button:**
```dart
SizedBox(
  width: buttonSize,
  height: buttonSize,
  child: IconButton(
    onPressed: state.isRunning ? pause : resume,
    padding: EdgeInsets.zero,
    icon: Icon(
      state.isRunning ? Icons.pause : Icons.play_arrow,
      size: buttonSize * 0.6,
      color: Colors.white,
    ),
  ),
)
```

**Undo button:**
```dart
SizedBox(
  width: buttonSize,
  height: buttonSize,
  child: Container(
    decoration: BoxDecoration(
      color: state.isRunning
          ? Colors.white.withOpacity(0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
    ),
    child: IconButton(
      onPressed: state.isRunning ? undo : null,
      padding: EdgeInsets.zero,
      icon: Text('↩️', style: TextStyle(fontSize: buttonSize * 0.55)),
    ),
  ),
)
```

**Properties:**
- Button size: Adaptive (6% of panel height, clamped 20-32px)
- Spacing between buttons: Adaptive (1.5% of panel height)
- Undo shows visual feedback when active (white 10% bg)
- Undo disabled when match paused

### 3.8 Timer Display

**Style:**
```dart
Text(
  '3:45',  // m:ss format
  style: TextStyle(
    color: Colors.white,
    fontSize: timerSize,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
  ),
)
```

**Properties:**
- Font: Monospace (for digit alignment)
- Color: White
- Size: Adaptive (13% of panel height, clamped 28-70px)
- Format: `m:ss` (e.g., 3:45, 10:00)
- Weight: Bold

---

## 4. Responsive Behavior

### 4.1 Adaptive Sizing

**All sizes based on available screen dimensions:**

| Element | Calculation | Min | Max |
|---------|-------------|-----|-----|
| Score | height × 20% | 36px | 100px |
| Timer | height × 13% | 28px | 70px |
| Button | height × 6% | 20px | 32px |
| Spacing | height × 1.5% | 2px | 8px |
| Match ID | height × 2.5% | 9px | 12px |

**Tool:** Use `LayoutBuilder` to get `constraints.maxHeight`

### 4.2 No Overflow

**Constraints:**
- All elements must fit within available space
- Use `mainAxisSize: MainAxisSize.min` for columns
- Clamp all size calculations to safe ranges
- Test on smallest target device (Pixel 6: 2400×1080)

### 4.3 Screen Coverage

**Goal:** 100% screen usage

**Implementation:**
- Row with `Expanded` children (no fixed widths except A/P column)
- SafeArea to respect notches
- No scrolling (everything visible at once)
- Uniform spacing distribution

---

## 5. Behavior Specifications

### 5.1 Scoring Actions

**Increment (+):**
1. User taps [+] button
2. Call `notifier.scorePt4(fighter)` (or pt3/pt2/adv/pen)
3. Count increases by 1
4. Total score updates automatically

**Decrement (-):**
1. User taps [-] button
2. Call `notifier.undo()`
3. Last action is reverted
4. Counts and total score update

**Button states:**
- [+] always enabled when match running
- [-] enabled only when count > 0 and match running
- All disabled when match paused

### 5.2 Match Control

**Pause:**
1. User taps pause button
2. Match state changes to paused
3. Icon changes to play_arrow
4. All scoring buttons disabled

**Resume:**
1. User taps play button
2. Match state changes to running
3. Icon changes to pause
4. All scoring buttons enabled

**Undo:**
1. User taps ↩️ button
2. Last scoring action is reverted
3. Visual feedback: button background briefly highlights
4. Disabled when match paused

### 5.3 Navigation

**Entry:** Automatically switches to horizontal mode when device rotates to landscape

**Exit:** Automatically switches to vertical mode when device rotates to portrait

**NO back button in UI** — rotation is the only navigation method

---

## 6. Visual Design

### 6.1 Color Scheme

**Background colors:**
- Left panel (scoring): `colors.surface`
- Right panel (timer): `Colors.black`
- Divider: `colors.outline` at 30% opacity

**Text colors:**
- Fighter names: `colors.onSurface`
- Counts: `colors.onSurface`
- Timer: `Colors.white`
- Match ID: `Colors.white` at 60% opacity

**Button colors:**
- [+]: `colors.primary`
- [-]: `colors.error`
- Pause/Play: `Colors.white`
- Undo: `Colors.white` (emoji)

**Badge colors:**
- Background: `colors.primary` at 12% opacity
- Border: `colors.primary` at 30% opacity
- Text: `colors.primary`

### 6.2 Typography

| Element | Size | Weight | Family | Spacing |
|---------|------|--------|--------|---------|
| Fighter name | 14px | Bold | Default | 0 |
| Badge | 12px | w600 | Default | 0.5 |
| Count (scoring) | 24px | Bold | Default | 0 |
| Count (A/P) | 14px | Bold | Default | 0 |
| Timer | Adaptive | Bold | Monospace | 0 |
| Score | Adaptive | Bold | Default | 0 |
| Match ID | Adaptive | w400 | Default | 0.5 |

### 6.3 Spacing

**Padding:**
- Fighter section: 6px horizontal, 4px vertical
- Badge: 8px horizontal, 3px vertical
- Score: Proportional to size
- Match ID: 6px horizontal, 2px vertical

**Gaps:**
- Between scoring columns: 4px
- Before A/P column: 8px
- Between A and P: 2px
- Between control buttons: Adaptive (1.5% height)
- Between panel sections: Adaptive (1.5% height)

### 6.4 Borders & Corners

**Border radius:**
- Badges: 6px
- Scores: 8px
- Match ID: 4px
- Undo button: 4px

**Border widths:**
- Badge border: 1px
- No borders elsewhere

---

## 7. Edge Cases

### 7.1 Very Small Screens
- All sizes clamp to minimums
- Layout remains readable
- Buttons maintain touch target size (min 18×18)

### 7.2 Very Large Screens
- All sizes clamp to maximums
- Prevents comically large UI
- Maintains visual hierarchy

### 7.3 Long Fighter Names
- Truncate with ellipsis if needed
- Max width: panel width minus padding

### 7.4 Zero Counts
- Display "0" (not empty)
- [-] button disabled
- Visual state unchanged

### 7.5 Match Paused
- All scoring buttons disabled
- Play icon shown
- Undo disabled
- Scores and timer still visible

---

## 8. Implementation Notes

### 8.1 File Location
`lib/features/match/widgets/horizontal_scoring_view.dart`

### 8.2 Dependencies
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/match_control_provider.dart';
```

### 8.3 Widget Structure
```
HorizontalScoringView (ConsumerWidget)
├── SafeArea
    └── Row
        ├── Expanded (flex: 4) - Scoring panel
        │   └── Container (surface bg)
        │       └── Column
        │           ├── Expanded - Fighter 1 section
        │           ├── Container (divider)
        │           └── Expanded - Fighter 2 section
        └── Expanded (flex: 1) - Timer panel
            └── Container (black bg)
                └── LayoutBuilder
                    └── Column (centered, min size)
                        ├── Match ID badge
                        ├── Fighter 1 score
                        ├── Control buttons row
                        ├── Timer
                        └── Fighter 2 score
```

### 8.4 Helper Functions
- `_parseColor(String hex, Color fallback)` - Parse hex color with fallback
- `_formatTime(int seconds)` - Format as m:ss
- `_buildFighterScoringPanel(...)` - Build one fighter's scoring section
- `_buildScoringColumn(...)` - Build +4/+3/+2 column
- `_buildAdvPenColumn(...)` - Build A/P column
- `_buildTimerPanel(...)` - Build right panel

### 8.5 State Management
- Read from: `matchControlProvider`
- Write to: `matchControlProvider.notifier`
- Reactive: Widget rebuilds on state changes

---

## 9. Testing Strategy

### 9.1 Visual Testing
- [ ] Renders correctly on Pixel 6 (2400×1080)
- [ ] Renders correctly on iPhone 15 Pro (2556×1179)
- [ ] No overflow on any element
- [ ] All text readable
- [ ] Fighter colors display correctly
- [ ] Contrast is good on all color combinations

### 9.2 Interaction Testing
- [ ] [+] buttons increment counts
- [ ] [-] buttons call undo
- [ ] Pause button works
- [ ] Undo button works
- [ ] Disabled states are correct
- [ ] Touch targets are comfortable (min 18×18)

### 9.3 Responsive Testing
- [ ] Adapts to screen height changes
- [ ] Sizes clamp to min/max correctly
- [ ] Layout doesn't break on edge cases

### 9.4 Integration Testing
- [ ] Connects to matchControlProvider
- [ ] State updates reflect in UI
- [ ] Undo reverts last action correctly

---

## 10. Future Enhancements

### 10.1 Not in this spec
- Orientation detection (separate PR)
- Mode switching animations (separate PR)
- Haptic feedback (separate PR)
- Accessibility improvements (separate PR)

### 10.2 Possible improvements
- Configurable flex ratio (let user adjust panel widths)
- Swipe gestures for undo
- Long-press for bulk increment
- Shake to undo

---

## 11. Approval Checklist

Before implementation begins:
- [ ] Spec reviewed by @negrunch
- [ ] Layout structure approved
- [ ] Component specifications approved
- [ ] Visual design approved
- [ ] Behavior specifications approved
- [ ] Edge cases covered
- [ ] Testing strategy approved

---

## 12. References

- Issue: #62
- Mockup image: https://github.com/user-attachments/assets/03d78f51-168a-4594-9988-20d3812c7fd7
- BJJ style guide: `projects/choke/BJJ_STYLE_GUIDE.md`

---

**END OF SPECIFICATION**
