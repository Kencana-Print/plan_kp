---
name: freee
colors:
  primary: "#285ac8"
  secondary: "#6e6b6b"
  success: "#00963c"
  warning: "#be8c14"
  danger: "#dc1e32"
  info: "#285ac8"
  background: "#ebf3ff"
  surface: "#ffffff"
  foreground: "#323232"
  border: "#e9e7e7"
  overlay: "rgba(0, 0, 0, 0.5)"
colors-dark:
  primary: "#73a5ff"
  secondary: "#8c8989"
  success: "#33b058"
  warning: "#d4a832"
  danger: "#e83a50"
  info: "#73a5ff"
  background: "#143278"
  surface: "#1e46aa"
  foreground: "#f0eded"
  border: "#3264dc"
typography:
  h1:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif"
    fontSize: 28px
    fontWeight: 700
    lineHeight: 1.3
  h2:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif"
    fontSize: 22px
    fontWeight: 600
    lineHeight: 1.35
  h3:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif"
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.4
  body-md:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.5
  body-sm:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif"
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.45
  body-xs:
    fontFamily: "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.4
spacing:
  xs: 0.25rem
  sm: 0.5rem
  md: 1rem
  lg: 1.5rem
  xl: 2rem
rounded:
  sm: 0.125rem
  md: 0.25rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
---

## Overview

Freee embodies the trustworthy precision of Japanese enterprise software — a calm, confident blue (#285ac8) that conveys reliability without being cold. The design language balances professional authority with approachable warmth. Every element communicates "your finances are in good hands."

## Colors

The palette is anchored by #285ac8 as the primary accent, with #73a5ff for dark mode.

### Foundation

Freee's color story centers on **enterprise blue** (#285ac8) — a trustworthy, stable hue that conveys professional competence. This is paired with warm gray surfaces that feel human rather than corporate.

### The Enterprise Blue System

**Primary — Freee Blue (#285ac8)**: The signature blue for all primary actions, links, and brand elements. Strong but not aggressive — trustworthy, not flashy.

**Secondary — Charcoal (#6e6b6b)**: A warm charcoal for secondary actions and supporting UI. Bridges the blue primary and neutral surfaces.

### Surface Hierarchy

| Level | Light Mode | Dark Mode | Use |
|-------|-----------|-----------|-----|
| Canvas | #ebf3ff | #143278 | Page background (light blue tint) |
| Surface | #ffffff | #1e46aa | Cards, elevated elements |
| Muted | #f7f5f5 | #143278 | Subtle backgrounds, columns |
| Foreground | #323232 | #f0eded | Text, content |

### Dark Mode: "Professional After Hours"

Dark mode shifts to a sophisticated dark palette — deep navy-blues maintain the enterprise feel while allowing the blue to remain the visual anchor.

**Core Principles:**

1. **Blue Remains Central**: The signature blue brightens appropriately but stays the primary accent
2. **Warm Neutrals**: Not pure grays — the warm undertone maintains the approachable enterprise feel
3. **Hierarchy Preserved**: The light blue canvas becomes dark, surface adapts for card contrast

**Dark Mode Token Mapping:**

| Light Mode | Dark Mode | Rationale |
|------------|-----------|-----------|
| #285ac8 (Primary) | #73a5ff | Brighter blue for dark backgrounds |
| #ebf3ff (Canvas) | #143278 | Dark navy canvas maintains enterprise feel |
| #ffffff (Surface) | #1e46aa | Blue-tinted surfaces adapt |
| #323232 (Text) | #f0eded | High contrast text |

### Semantic Colors

| Token | Light | Dark |
|-------|-------|------|
| Background | #ebf3ff | #143278 |
| Surface | #ffffff | #1e46aa |
| Foreground | #323232 | #f0eded |
| Border | #e9e7e7 | #3264dc |
| Primary | #285ac8 | #73a5ff |
| Secondary | #6e6b6b | #8c8989 |
| Success | #00963c | #33b058 |
| Warning | #be8c14 | #d4a832 |
| Danger | #dc1e32 | #e83a50 |
| Info | #285ac8 | #73a5ff |

### Signature Details

- **Light Blue Canvas**: #ebf3ff gives the entire app a calm, professional tint — not stark white, not boring gray
- **Deep Navigation Blue**: #143278 for header/navigation elements — creates authority without being heavy
- **Warm Charcoal Text**: #6e6b6b and #323232 are warm, readable, professional

## Typography

### Font Stack

**System Stack** — Uses `-apple-system, BlinkMacSystemFont, 'Helvetica Neue', 'ヒラギノ角ゴ ProN', Hiragino Kaku Gothic ProN, Arial, 'メイリオ', Meiryo, sans-serif` for multi-script support including Japanese. Clean, professional, universally readable.

### Type Scale

| Role | Size | Weight | Line Height | Character |
|------|------|--------|-------------|-----------|
| H1 | 28px | 700 | 1.3 | Page titles |
| H2 | 22px | 600 | 1.35 | Section headers |
| H3 | 18px | 600 | 1.4 | Card titles |
| Body | 15px | 400 | 1.5 | Content, descriptions |
| Small | 13px | 400 | 1.45 | Secondary text |
| Micro | 12px | 500 | 1.4 | Labels, badges |

## Layout & Spacing

The spacing system follows a 4px grid scale based on 0.25rem increments:

| Token | Value | Usage |
|-------|-------|-------|
| xs | 0.25rem | Tight component spacing |
| sm | 0.5rem | Standard element gaps |
| md | 1rem | Card padding, section spacing |
| lg | 1.5rem | Major section gaps |
| xl | 2rem | Page section separation |

With 8px base and Japanese-influenced precision: 0.25rem (4px) for tight spacing within components, 0.5rem (8px) for standard element gaps, 0.75rem (12px) for input padding, 1rem (16px) for card padding, 1.5rem (24px) for major section gaps, 2rem (32px) for page section separation.

## Elevation & Depth

### Shadow Philosophy

Freee uses **layered shadow elevation** — multiple shadow layers create depth without harsh edges. The effect is professional and confident, not playful.

| Level | Treatment | Use |
|-------|-----------|-----|
| Level 0 | none | Flat elements |
| Level 1 | 0 0 1rem rgba(0,0,0,0.1), 0 0.125rem 0.25rem rgba(0,0,0,0.2) | Cards, subtle hover |
| Level 2 | 0 0 1.5rem rgba(0,0,0,0.1), 0 0.25rem 0.5rem rgba(0,0,0,0.2) | Dropdowns, elevated cards |
| Level 3 | 0 0 2rem rgba(0,0,0,0.1), 0 0.375rem 0.75rem rgba(0,0,0,0.2) | Modals, popovers |

### Border Usage

Freee uses **subtle borders** in combination with shadows:
- Cards have #e9e7e7 borders with level-1 shadow
- Inputs use #e9e7e7 default, #d7d2d2 on hover
- Disabled states reduce opacity rather than change color

## Shapes

The shape language uses 0.125rem as the base corner radius, reflecting professional enterprise restraint:

| Token | Value | Usage |
|-------|-------|-------|
| sm | 0.125rem | Subtle rounding |
| md | 0.25rem | Buttons, inputs |
| lg | 0.5rem | Cards |
| xl | 0.75rem | Larger containers |
| full | 9999px | Pills, badges |

The minimal 0.125rem sm radius keeps the enterprise feel crisp and professional. Cards use 0.5rem lg radius — rounded enough to feel intentional but not playful. Pill shapes (9999px) are reserved for badges and labels only.

## Components

### Buttons & Interaction

**Primary CTA**: Freee Blue (#285ac8) background, white text, subtle shadow. On hover: darkens to #1e46aa. On press: further darkens to #23418c. The trustworthy action color.

**Secondary**: Charcoal (#6e6b6b) background for secondary actions. Establishes hierarchy without competing with blue.

**Ghost/Outline**: Transparent with blue border — for tertiary actions where filled buttons feel too prominent.

### Inputs & Selection

**Text Inputs**: White background on light mode, #e9e7e7 border. Focus state: blue border with subtle glow ring. Placeholder uses #aaa7a7.

**Select Dropdowns**: Consistent with input styling, chevron indicator. Dropdown panel uses level-2 shadow.

**Checkboxes**: Custom styled with blue check when active. Smooth scale animation on check.

**Switches**: iOS-style toggle with blue when active, gray (#bebaba) when inactive.

### Cards & Containers

**Cards**: White background (#ffffff), subtle border (#e9e7e7), level-1 shadow, 8px corner radius. Content breathing room with 16-24px padding.

**Column/Table Background**: #f7f5f5 for alternating rows — subtle but effective data table styling.

### Feedback Components

**Alerts**: Left-bordered (4px) in semantic color. Background uses subtle tint of semantic color at low opacity.

**Toasts**: Floating panel with shadow, icon + message layout, auto-dismiss after 4 seconds.

**Badges**: Small pill shape, uppercase micro text. Filled variant uses solid semantic color.

## Do's and Don'ts

### Do

- **Use Freee Blue for primary CTAs** — it's the brand anchor, immediately recognizable
- **Apply the light blue canvas tint** — #ebf3ff creates professional calm, not stark white
- **Use warm charcoal for secondary text** — #6e6b6b reads warmer than neutral gray
- **Maintain blue in dark mode** — brighten to #73a5ff but keep it central
- **Use layered shadows for elevation** — the dual-layer shadow creates confident depth
- **Keep cards white against the blue-tinted canvas** — clear hierarchy through contrast

### Don't

- **Don't use aggressive accent colors** — enterprise blue is calm, professional, not flashy
- **Don't use stark white canvas** — the #ebf3ff tint is part of the professional identity
- **Don't use playful shadows** — keep elevation serious, confident, enterprise-appropriate
- **Don't use pure black text** — warm charcoal (#323232) is more approachable
- **Don't use rounded corners > 8px** — keep rectangular elements crisp, professional
- **Don't center-align body text** — left alignment for professional readability
