# BJJ Brand Colors - Style Guide

A powerful color palette extracted from Brazilian Jiu-Jitsu imagery. Four essential colors that embody discipline, growth, achievement, and purity.

---

## Color Palette

### Navy Black — The Foundation

| Format | Value |
|--------|-------|
| HEX | #121A2E |
| HSL | hsl(220, 45%, 12%) |
| RGB | rgb(18, 26, 46) |
| CSS Variable | var(--bjj-navy) |
| Tailwind | bg-bjj-navy |

**Description:** Deep, authoritative background representing discipline and mastery.  
**Usage:** Backgrounds, headers, footers, overlays

---

### BJJ Green — The Growth

| Format | Value |
|--------|-------|
| HEX | #1BA34E |
| HSL | hsl(145, 72%, 35%) |
| RGB | rgb(27, 163, 78) |
| CSS Variable | var(--bjj-green) |
| Tailwind | bg-bjj-green |

**Description:** Vibrant green symbolizing growth, progress, and the journey through belt ranks.  
**Usage:** Primary actions, CTAs, success states, highlights

---

### Championship Gold — The Achievement

| Format | Value |
|--------|-------|
| HEX | #F5B800 |
| HSL | hsl(45, 95%, 55%) |
| RGB | rgb(245, 184, 0) |
| CSS Variable | var(--bjj-gold) |
| Tailwind | bg-bjj-gold |

**Description:** Bold gold representing achievement, excellence, and championship spirit.  
**Usage:** Accents, badges, awards, special highlights

---

### Pure White — The Clarity

| Format | Value |
|--------|-------|
| HEX | #FFFFFF |
| HSL | hsl(0, 0%, 100%) |
| RGB | rgb(255, 255, 255) |
| CSS Variable | var(--bjj-white) |
| Tailwind | bg-bjj-white |

**Description:** Clean white for clarity, purity, and the traditional white gi.  
**Usage:** Text on dark backgrounds, cards, clean spaces

---

## Color Combinations

### Primary Dark
- Background: Navy Black (#121A2E)
- Text: White (#FFFFFF)
- Accent: Green (#1BA34E)

### Primary Light
- Background: White (#FFFFFF)
- Text: Navy Black (#121A2E)
- Accent: Gold (#F5B800)

### Championship
- Background: Navy Black (#121A2E)
- Text: Gold (#F5B800)
- Accent: White (#FFFFFF)

### Growth
- Background: Green (#1BA34E)
- Text: White (#FFFFFF)
- Accent: Gold (#F5B800)

### Achievement
- Background: Gold (#F5B800)
- Text: Navy Black (#121A2E)
- Accent: White (#FFFFFF)

### Minimal
- Background: White (#FFFFFF)
- Text: Navy Black (#121A2E)
- Accent: Green (#1BA34E)

---

## Usage Guidelines

### Primary Actions
Use BJJ Green for primary CTAs, buttons, and interactive elements.

### Highlights & Awards
Use Championship Gold for badges, achievements, and special callouts.

### Dark Backgrounds
Use Navy Black for headers, footers, and immersive sections.

### Clean Spaces
Use Pure White for cards, content areas, and readable sections.

---

## CSS Implementation

### CSS Custom Properties
```css
:root {
  --bjj-navy: 220 45% 12%;
  --bjj-green: 145 72% 35%;
  --bjj-gold: 45 95% 55%;
  --bjj-white: 0 0% 100%;
}
```

### Tailwind Configuration
```js
colors: {
  bjj: {
    navy: 'hsl(var(--bjj-navy))',
    green: 'hsl(var(--bjj-green))',
    gold: 'hsl(var(--bjj-gold))',
    white: 'hsl(var(--bjj-white))'
  }
}
```

---

## Quick Reference

| Color | HEX | Primary Use |
|-------|-----|-------------|
| Navy Black | #121A2E | Backgrounds |
| BJJ Green | #1BA34E | Actions & CTAs |
| Championship Gold | #F5B800 | Accents & Awards |
| Pure White | #FFFFFF | Text & Cards |

---

## Color Swatches

```
+------------------+------------------+------------------+------------------+
|                  |                  |                  |                  |
|   Navy Black     |   BJJ Green      | Championship Gold|   Pure White     |
|    #121A2E       |    #1BA34E       |    #F5B800       |    #FFFFFF       |
|                  |                  |                  |                  |
+------------------+------------------+------------------+------------------+
```

---

*Extracted from BJJ Gi imagery. Vibed with [Shakespeare](https://shakespeare.diy)*
