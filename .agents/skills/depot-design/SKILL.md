---
name: depot-design
description: "Use this skill whenever designing, modifying, or creating UI components, pages, layouts, or stylesheets following the Depot design system in DESIGN.md."
---

# Depot Design System Skill

The Depot design language is modeled after a **dark server-rack terminal / developer console**. It features a near-black canvas, hairline green/neutral borders, a tri-tonal typography system, and a single vivid green accent reserved exclusively for the primary call-to-action.

Always reference `DESIGN.md` in the project root for the authoritative design specifications.

---

## 1. Color Palette & Tailwind Tokens

The following colors are configured in `assets/css/app.css` via Tailwind v4 `@theme`:

| Name | Hex | Tailwind Class | Role |
| :--- | :--- | :--- | :--- |
| **Signal Green** | `#71d083` | `bg-signal-green`, `text-signal-green` | **Primary CTA fill ONLY** or small active status indicator. Never use for secondary buttons or large cards. |
| **LED Green** | `#366740` | `border-led-green`, `bg-led-green` | Border for the primary CTA button. Supporting dark accent. |
| **Moss Border** | `#2d5736` | `border-moss-border` | Subtle green-tinted border for highlighted cards or announcement banner bottom borders. |
| **Forest Wash** | `#1d3a24` | `bg-forest-wash` | Tinted background for spotlighted/featured cards or text selections. |
| **Fern Ground** | `#1b2a1e` | `bg-fern-ground` | Deep green surface for category badges and tags. |
| **Link Blue** | `#70b8ff` | `text-link-blue` | Inline text links only (never buttons or cards). |
| **Lilac Accent** | `#baa7ff` | `text-lilac-accent` | Subtle secondary decorative icon accent. |
| **Plum Edge** | `#291f43` | `border-plum-edge` | Violet border tint for grouped metadata tags. |
| **Iris Border** | `#473876` | `border-iris-border` | Mid-violet inline code links and label borders. |
| **Lavender Mist** | `#e2ddfe` | `text-lavender-mist` | Pale lavender text accent for highlighted tags. |
| **Carbon** | `#04040b` | `bg-carbon` | **Page Canvas** — deepest near-black base. |
| **Graphite** | `#121113` | `bg-graphite` | **Level 1 Surface** — feature cards, nav header, content panels. |
| **Obsidian** | `#1a191b` | `bg-obsidian` | **Level 2 Surface** — nested cards, secondary panels, footer, input fields. |
| **Slate** | `#232225` | `bg-slate` | **Level 3 Surface** — interactive hover surfaces, button backgrounds. |
| **Basalt** | `#2b292d` | `border-basalt` | **Primary Hairline Border** — 1px dividers, card outlines, separators. |
| **Iron** | `#323035` | `border-iron` | Secondary column dividers (e.g. CI workflow vertical line). |
| **Pewter** | `#3c393f` | `border-pewter` | Hover state border for ghost buttons. |
| **Steel** | `#49474e` | `border-steel` | Subtle structural lines, muted icon strokes. |
| **Fog** | `#7c7a85` | `text-fog` | Inactive nav links, muted body, footer copy, pending dots. |
| **Silver** | `#b5b2bc` | `text-silver` | Secondary text, placeholder text, job status text. |
| **Ash** | `#eeeef0` | `text-ash` | **Primary Body Text** — high-contrast off-white reading copy. |
| **Chalk** | `#e5e5e5` | `text-chalk` | **Primary Headings** — brightest text for headlines. |

---

## 2. Typography & The Inverted Tracking Rule

The system uses three Google Font families:
1. **Red Hat Display** (`font-display`): Hero headlines & section titles.
2. **Red Hat Text** (`font-text`): Body copy, navigation links, button labels, UI controls.
3. **Red Hat Mono** (`font-mono`): Code snippets, terminal labels, status indicators, build steps.

### Crucial Tracking Rule
- **Display type (36px+)**: **Negative tracking** (`tracking-[-0.025em]`). This compresses headlines into an industrial, tight look.
- **Body & UI type (10-20px)**: **Positive tracking** (`tracking-[0.025em]`). This loosens letterforms so dark-mode body text breathes and reads cleanly.
- *Never flatten both to normal tracking.*

---

## 3. Radii, Borders, and Elevation

- **Radii**:
  - `rounded-md` (6px): Buttons, input fields, cards, dialogs.
  - `rounded-xs` (2px): Nav items, category badges/tags, icons.
  - *Never use large border radii (12px+, 24px+, or pill shapes) for cards or buttons.*
- **Elevation**:
  - **No Drop Shadows**. Elevation is communicated strictly by surface lift:
    `bg-carbon` (canvas) → `bg-graphite` (card) → `bg-obsidian` (nested element)
  - Edge definition uses 1px hairline `border border-basalt` (`#2b292d`).
  - Optional top highlight: `shadow-subtle` (`inset 0 1px 0 0 rgba(255, 255, 255, 0.06)`).

---

## 4. Standard Component Recipes

### Primary CTA Button (Maximum 1 per screen)
```html
<button class="inline-flex items-center justify-center gap-2 rounded-md bg-signal-green px-5 py-2.5 text-sm font-medium tracking-[0.025em] text-carbon border border-led-green hover:brightness-105 active:brightness-95 transition-all">
  Get started &rarr;
</button>
```

### Ghost / Outline Button (Secondary Action)
```html
<button class="inline-flex items-center justify-center gap-2 rounded-md bg-transparent px-5 py-2.5 text-sm font-medium tracking-[0.025em] text-ash border border-basalt hover:border-pewter hover:text-chalk transition-all">
  Documentation
</button>
```

### Feature Card
```html
<div class="rounded-md bg-graphite border border-basalt p-6 flex flex-col gap-4 shadow-subtle">
  <div class="text-xs uppercase font-medium tracking-[0.025em] text-signal-green">
    Fast Builds
  </div>
  <h3 class="text-xl font-semibold tracking-[-0.015em] text-chalk font-display">
    Container Build Acceleration
  </h3>
  <p class="text-sm leading-relaxed text-silver font-text tracking-[0.025em]">
    Accelerate Docker builds with remote native NVMe caches and parallelized layers.
  </p>
</div>
```

### Tag / Badge
```html
<span class="inline-flex items-center rounded-xs bg-fern-ground border border-moss-border px-2 py-0.5 text-xs uppercase font-medium tracking-[0.025em] text-signal-green">
  Production Ready
</span>
```

### CI / Terminal Panel
```html
<div class="rounded-md bg-graphite border border-basalt overflow-hidden shadow-subtle">
  <div class="bg-obsidian border-b border-basalt px-4 py-2.5 flex items-center justify-between">
    <span class="font-mono text-xs uppercase text-fog tracking-[0.025em]">CI Workflow</span>
    <span class="inline-block h-2 w-2 rounded-full bg-signal-green"></span>
  </div>
  <div class="p-4 font-mono text-sm space-y-2">
    <div class="flex items-center justify-between text-silver">
      <span class="text-ash">Job picked up</span>
      <span class="text-signal-green">0.4s</span>
    </div>
    <div class="flex items-center justify-between text-silver">
      <span class="text-ash">Building image</span>
      <span class="text-signal-green">1.2s</span>
    </div>
  </div>
</div>
```

---

## 5. Strict Do's & Don'ts

### Do
- Use `#04040b` (`bg-carbon`) for the page background.
- Reserve Signal Green (`#71d083`) exclusively for the single primary CTA.
- Separate surfaces with 1px `border-basalt` (`#2b292d`).
- Keep border radii tight (6px for cards/buttons, 2px for tags).
- Use `text-chalk` (`#e5e5e5`) for headings and `text-ash` (`#eeeef0`) for body.

### Don't
- **Never** use drop shadows (`shadow-lg`, `shadow-md`, etc.).
- **Never** use pure white text (`text-white` / `#ffffff`). Use `text-chalk` or `text-ash`.
- **Never** use Link Blue (`#70b8ff`) for buttons or cards; only use for inline body text links.
- **Never** use 12px+ or pill-shaped cards or buttons.
- **Never** use Signal Green for backgrounds of cards, tags, or secondary buttons.
