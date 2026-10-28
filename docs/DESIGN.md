# Gəlir-Çıxar: Design System

Offline personal income/expense tracker for Android. Built with Flutter and Material 3.
The UI is Azerbaijani (default) and English. The base currency is AZN (₼).

The implementation lives in `lib/core/theme.dart`: `AppTheme.light`, `AppTheme.dark`, the
`AppColors` ThemeExtension, and the `AppSpacing` / `AppRadius` / `AppSizes` constants.

> **v1.1** (2026-10-28) is specified in §9–§17 at the end of this file. Where v1.1 changes a
> v1.0 value, the v1.0 table below shows the new value with the old one in brackets.

---

## 1. Principles

1. **Money is always readable.** Amounts use tabular figures, a sign (+/−) and colour, so
   meaning never depends on colour alone (colour-blind safe).
2. **Calm surfaces, loud numbers.** Neutral teal-tinted surfaces. Colour is spent on
   income/expense, budget state and categories.
3. **One-thumb reach.** Primary actions (FAB, keypad, Save) sit in the lower half of the screen.
   Touch targets are at least 48dp.
4. **Same meaning in both themes.** Semantic roles stay the same between themes; only the
   tones change.

---

## 2. Colour

Brand seed: **Deep Teal `#00696E`**. It is neither green (income) nor red (expense), so the
brand never gets confused with money semantics.
The ColorScheme is generated with `ColorScheme.fromSeed(seedColor: #00696E)` and then the
roles below are overridden so the exact values (and their contrast) are fixed.

### 2.1 Core roles

| Role | Light | Dark | Use |
|---|---|---|---|
| primary | `#00696E` | `#6FD5DC` | FAB, filled buttons, selected nav, links |
| onPrimary | `#FFFFFF` | `#00373A` | Text/icons on primary |
| primaryContainer | `#9CF0F6` | `#004F53` | Selected chips, nav indicator |
| onPrimaryContainer | `#002022` | `#9CF0F6` | |
| secondary | `#4A6365` | `#B1CBCD` | Secondary actions |
| tertiary | `#4C5F7C` | `#B4C8E9` | Accents (rare) |
| surface | `#F8FAF9` | `#0F1416` | Scaffold background |
| surfaceContainerLowest | `#FFFFFF` | `#0A0F10` | |
| surfaceContainerLow | `#F2F5F4` | `#171D1E` | Cards, list groups |
| surfaceContainer | `#ECF0EF` | `#1A2124` | Nav bar, bottom sheets |
| surfaceContainerHigh | `#E9EFEE` | `#232B2E` | Input fill, keypad keys |
| surfaceContainerHighest | `#E0E6E5` | `#2D3639` | Progress track, disabled fill |
| onSurface | `#171D1E` | `#E1E4E4` | Primary text |
| onSurfaceVariant | `#43494B` | `#BEC8C9` | Secondary text, icons |
| outline | `#6F797A` | `#89938F` | Input borders, dividers that must be visible |
| outlineVariant | `#BFC8C9` | `#3F484A` | Decorative dividers |
| error | `#B3261E` | `#FFB4AB` | Form errors (same as danger) |

### 2.2 Semantic money and budget colours (`AppColors` ThemeExtension)

| Token | Light | Dark | Meaning |
|---|---|---|---|
| income | `#146C35` (v1.0: `#17763A`) | `#6FD892` | Income amounts, "+" |
| incomeContainer / on | `#D3F4DC` / `#0E5128` | `#14432A` / `#C6F2D3` | Income chip, type toggle |
| expense | `#B42229` (v1.0: `#C0262D`) | `#FF8A84` | Expense amounts, "−" |
| expenseContainer / on | `#FFDAD7` / `#7A1015` | `#5C1518` / `#FFDAD7` | Expense chip, type toggle |
| transfer | `#2F5D8A` | `#9DC4EE` | Transfers between accounts (no sign, ⇄ icon) |
| transferContainer / on | `#D4E5F7` / `#1A3F63` | `#1E3A57` / `#D4E5F7` | |
| warning (text) | `#8A5300` | `#FFB547` | Budget ≥ 80 %: label text |
| warningFill (bar) | `#C07600` | `#FFB547` | Budget ≥ 80 %: progress fill |
| warningContainer / on | `#FFE3BF` / `#5C3600` | `#4A3000` / `#FFE3BF` | Budget warning banner |
| danger | `#B3261E` | `#FFB4AB` | Budget ≥ 100 %: text and fill |
| dangerContainer / on | `#FFDAD6` / `#410002` | `#93000A` / `#FFDAD6` | Over-budget banner |
| balanceCard (gradient start) | `#00585C` | `#163B3E` | Hero balance card |
| balanceCardEnd | `#006A6F` (v1.0: `#00797F`) | `#1C4649` (v1.0: `#1E4A4E`) | |
| onBalanceCard | `#FFFFFF` | `#E1E4E4` | |
| onBalanceCardVariant | `#CDEFF0` | `#A9CFD1` | Labels on the hero card |
| balanceIncome / balanceExpense | `#B6F2C8` / `#FFD6D2` (v1.0: `#FFC9C5`) | `#6FD892` / `#FFA19B` (v1.0: `#FF8A84`) | Month income/expense on the hero card |

Budget state rule (by `spent / limit`):

| Ratio | State | Fill | Label |
|---|---|---|---|
| < 0.80 | normal | category colour (or primary) | onSurfaceVariant |
| 0.80 – 0.999 | warning | warningFill | warning + ⚠ icon |
| ≥ 1.00 | danger | danger, bar clamped to 100 % | danger + "Limit aşıldı / Over budget" |

### 2.3 Categorical palette (categories and chart slices)

There are 12 mid-luminance hues. Each one keeps **at least 3:1 non-text contrast** against the
light card (`#FFFFFF`), the light surface (`#F8FAF9`), the dark card (`#1A2124`) and the dark
surface (`#0F1416`). That meets WCAG 1.4.11 for graphical objects, so the same list works in
both themes with no swap. The order is chosen so that neighbouring slices differ clearly in
hue and lightness.

| # | Name (az / en) | Hex | vs #FFF | vs #F8FAF9 | vs #1A2124 | vs #0F1416 | Suggested default category |
|---|---|---|---|---|---|---|---|
| 0 | Mavi / Blue | `#2F7ED8` | 4.12 | 3.93 | 3.96 | 4.50 | Nəqliyyat / Transport |
| 1 | Narıncı / Orange | `#E8590C` | 3.58 | 3.42 | 4.56 | 5.18 | Qida / Food |
| 2 | Yaşıl / Green | `#2B9A66` | 3.55 | 3.39 | 4.60 | 5.23 | Maaş / Salary |
| 3 | Moruq / Raspberry | `#D6336C` | 4.62 | 4.40 | 3.53 | 4.02 | Sağlamlıq / Health |
| 4 | Bənövşəyi / Violet | `#7950F2` | 4.95 | 4.72 | 3.30 | 3.75 | Əyləncə / Entertainment |
| 5 | Firuzəyi / Teal | `#0C8599` | 4.35 | 4.15 | 3.75 | 4.27 | Kommunal / Utilities |
| 6 | Xardal / Mustard | `#B07D00` | 3.63 | 3.47 | 4.49 | 5.11 | Alış-veriş / Shopping |
| 7 | Şifer / Slate | `#6B7C93` | 4.26 | 4.06 | 3.83 | 4.35 | Digər / Other |
| 8 | Lavanda / Periwinkle | `#5C7CFA` | 3.67 | 3.50 | 4.44 | 5.05 | Təhsil / Education |
| 9 | Zeytun / Olive | `#74872A` | 4.01 | 3.82 | 4.07 | 4.63 | Ev / Home |
| 10 | Bənövşə / Purple | `#AE3EC9` | 4.85 | 4.62 | 3.37 | 3.83 | Hədiyyə / Gifts |
| 11 | Kərpic / Sienna | `#B5603A` | 4.47 | 4.26 | 3.65 | 4.15 | Kafe-restoran / Dining |

Usage rules:
- Category icons are drawn **white on a filled circle** of the category colour (the white
  glyph is decorative; the category name next to it is the accessible label). White icons reach
  3.55–4.95:1 on these fills.
- Never put category-coloured **text** on the surface. Use onSurface text with a colour dot.
- Pie chart: slices in palette order sorted by value, descending. If there are more than 7
  categories, merge the rest into "Digər / Other" in slate `#6B7C93`. Leave 2dp gaps between
  slices (`sectionsSpace: 2`) so neighbours are separated without relying on colour.
- Bar chart (by month): income bars use `income`, expense bars use `expense` (semantic, not
  categorical), and the legend always shows text labels.
- Store the **palette index** (0–11) in the database rather than a hex value, so the palette
  can be tuned later.

### 2.4 WCAG AA contrast: text colours (computed, WCAG 2.x relative luminance)

AA needs 4.5:1 for normal text and 3:1 for large text (≥ 18.66px bold / 24px) and UI graphics.

**Light theme**

| Foreground | on surface `#F8FAF9` | on card `#FFFFFF` | Result |
|---|---|---|---|
| onSurface `#171D1E` | 16.28 | 17.06 | AAA |
| onSurfaceVariant `#43494B` | 8.74 | 9.16 | AAA |
| primary `#00696E` | 6.17 | 6.47 | AA |
| income `#146C35` (v1.1) | 6.21 | 6.51 | AA |
| expense `#B42229` (v1.1) | 6.26 | 6.56 | AA |
| transfer `#2F5D8A` | 6.56 | 6.88 | AA |
| warning `#8A5300` | 6.04 | 6.33 | AA |
| danger `#B3261E` | 6.24 | 6.54 | AA |
| outline `#6F797A` (non-text) | 4.27 | 4.48 | ≥ 3:1 UI |
| warningFill `#C07600` (bar) | — | 3.60 | ≥ 3:1 UI |

**Dark theme**

| Foreground | on surface `#0F1416` | on card `#1A2124` | Result |
|---|---|---|---|
| onSurface `#E1E4E4` | 14.51 | 12.76 | AAA |
| onSurfaceVariant `#BEC8C9` | 10.86 | 9.55 | AAA |
| primary `#6FD5DC` | 10.80 | 9.50 | AAA |
| income `#6FD892` | 10.52 | 9.26 | AAA |
| expense `#FF8A84` | 8.15 | 7.16 | AAA |
| transfer `#9DC4EE` | 10.22 | 8.99 | AAA |
| warning `#FFB547` | 10.56 | 9.29 | AAA |
| danger `#FFB4AB` | 10.93 | 9.61 | AAA |
| outline `#89938F` (non-text) | 5.86 | 5.15 | ≥ 3:1 UI |

**Paired surfaces**

| Pair | Ratio |
|---|---|
| onPrimary `#FFFFFF` on primary `#00696E` (light) | 6.47 |
| onPrimary `#00373A` on primary `#6FD5DC` (dark) | 7.61 |
| onIncomeContainer on incomeContainer (light / dark) | 7.97 / 9.13 |
| onExpenseContainer on expenseContainer (light / dark) | 8.50 / 10.32 |
| onTransferContainer on transferContainer (light / dark) | 8.45 / 9.09 |
| onWarningContainer on warningContainer (light / dark) | 8.57 / 9.91 |
| onBalanceCard on balanceCard (light / dark) | 8.23 / 9.49 |
| onBalanceCardVariant on balanceCard (light / dark) | 6.74 / 7.25 |
| balanceIncome on balanceCard (light / dark) | 6.48 / 6.89 (on the v1.1 end colour: 5.02 / 5.89) |
| balanceExpense on balanceCard (light / dark), v1.1 values | 6.20 / 6.26 (on the end colour: 4.80 / 5.35) |
| onSurface on surfaceContainerHigh (dark, keypad keys) | 11.27 |
| onSurfaceVariant on surfaceContainerHigh (light / dark) | 7.87 / 8.44 |

Every text pairing passes AA at normal size. Ratios were measured against the gradient's
*start* colour, which is the darker end. **v1.1** darkened the end colours and lightened
`balanceExpense`, so every on-card colour now passes 4.5:1 on *both* ends of the gradient
(§12.4). The v1.0 rule "keep small labels on the darker half" is no longer needed.

---

## 3. Typography

Font: the platform default (Roboto on Android). No custom font package is used. Roboto
covers every Azerbaijani letter (ə Ə ğ ı İ ö ş ç ü) and the manat sign ₼ (U+20BC) on
Android 8+. **All amounts use `FontFeature.tabularFigures()`** so columns line up.

| Token (M3 role) | Size / line height | Weight | Letter spacing | Use |
|---|---|---|---|---|
| displaySmall | 36 / 44 | 600 | −0.5 | Balance on hero card |
| headlineMedium | 28 / 36 | 600 | −0.25 | Amount being typed in the keypad display |
| headlineSmall | 24 / 32 | 600 | 0 | Screen titles (large app bar) |
| titleLarge | 20 / 28 | 600 | 0 | Section headers, dialog titles |
| titleMedium | 16 / 24 | 600 | 0.1 | Card titles, list tile title |
| titleSmall | 14 / 20 | 600 | 0.1 | Grouped list date headers |
| bodyLarge | 16 / 24 | 400 | 0.15 | Inputs, body copy |
| bodyMedium | 14 / 20 | 400 | 0.25 | List tile subtitle, descriptions |
| bodySmall | 12 / 16 | 400 | 0.4 | Hints, captions, chart axes |
| labelLarge | 14 / 20 | 600 | 0.1 | Buttons, tile amount |
| labelMedium | 12 / 16 | 600 | 0.5 | Chips, nav labels |
| labelSmall | 11 / 16 | 500 | 0.5 | Badges, percentage on bars |

Extra styles in `AppTextStyles`:
- `amountHero`: displaySmall + tabular figures, used for the balance.
- `amountTile`: titleMedium, weight 600, tabular figures, used for list amounts.
- `amountInput`: 40 / 48, weight 600, tabular figures, used in the keypad display.

Azerbaijani text runs about 15–25 % longer than English ("Əməliyyatlar" vs "Transactions"). Nav
labels must fit at 12sp in a 72dp column, so allow `TextOverflow.ellipsis` and never hard-code
widths. Test with text scaling at 200 %.

---

## 4. Spacing, radius, elevation, sizes

4dp base grid.

| Spacing token | dp | Typical use |
|---|---|---|
| `AppSpacing.xxs` | 2 | Icon to text inside a chip |
| `AppSpacing.xs` | 4 | Tight stacks |
| `AppSpacing.sm` | 8 | Between related items, chip gap |
| `AppSpacing.md` | 12 | Tile vertical padding, card inner gaps |
| `AppSpacing.lg` | 16 | Screen side gutter, card padding |
| `AppSpacing.xl` | 24 | Between sections |
| `AppSpacing.xxl` | 32 | Hero padding, empty-state gaps |
| `AppSpacing.xxxl` | 48 | Top of the lock screen |

| Radius token | dp | Use |
|---|---|---|
| `AppRadius.xs` | 4 | Progress bars |
| `AppRadius.sm` | 8 | Chips, small tags |
| `AppRadius.md` | 12 | Inputs, list group, buttons |
| `AppRadius.lg` | 16 | Cards, keypad keys, FAB |
| `AppRadius.xl` | 24 | Hero balance card |
| `AppRadius.sheet` | 28 | Bottom sheet top corners |
| `AppRadius.full` | 999 | Pills, avatars, PIN dots |

Elevation: M3 tonal elevation only (surfaceContainer tones). Cards use elevation 0. The FAB
uses elevation 3. Bottom sheets use surfaceContainerLow with no shadow tint.

Sizes (`AppSizes`): minimum touch target 48, list tile min height 64, category avatar 40,
keypad key height 64, PIN key 72, PIN dot 14, progress bar height 8, FAB 56, nav bar 80.

Motion: 150ms for state changes (`Curves.easeOut`), 250ms for page transitions and sheets
(`Curves.easeOutCubic`), 600ms for progress bars and chart entry. Respect
`MediaQuery.disableAnimations`; when it is true, use 0ms.

---

## 5. Amount formatting

Use `intl` `NumberFormat` with a fixed pattern. Do not rely on locale currency symbols,
because `az` CLDR uses "₼" placed after the number, and the app's own style should stay
deterministic.

| Locale | Pattern | Example positive | Example negative |
|---|---|---|---|
| `az` | grouping = U+00A0 (no-break space), decimal = `,`, symbol after with a no-break space | `1 234,56 ₼` | `−1 234,56 ₼` |
| `en` | grouping = `,`, decimal = `.`, symbol before, no space | `₼1,234.56` | `−₼1,234.56` |

Sign and colour rules:

| Type | Prefix | Colour | Example (az / en) |
|---|---|---|---|
| Income | `+` (U+002B) followed by a thin space U+2009 | `income` | `+ 250,00 ₼` / `+ ₼250.00` |
| Expense | `−` (U+2212 minus, not a hyphen) followed by a thin space | `expense` | `− 18,40 ₼` / `− ₼18.40` |
| Transfer | none, with a ⇄ icon | `transfer` | `500,00 ₼` |
| Balance (total) | `−` only if negative | onSurface (or onBalanceCard); expense colour if negative | `3 210,75 ₼` |

- Always show 2 decimals in lists and totals. Compact form (`1,2K ₼` / `₼1.2K`) is used only
  on chart axes.
- Screen readers: give every amount a `Semantics(label:)` such as "Gəlir 250 manat" /
  "Income 250 manat", so the sign is spoken.
- Non-base-currency accounts (USD/EUR) show their own code after the amount (`120,00 USD`) and
  the AZN equivalent in bodySmall below it.

Reference implementation (Dart):

```dart
String formatAmount(double v, String lang) {
  final abs = v.abs();
  if (lang == 'az') {
    final s = NumberFormat('#,##0.00', 'en').format(abs)
        .replaceAll(',', ' ').replaceAll('.', ',');
    return '$s ₼';
  }
  return '₼${NumberFormat('#,##0.00', 'en').format(abs)}';
}
String signed(double v, TxType t, String lang) => switch (t) {
  TxType.income  => '+ ${formatAmount(v, lang)}',
  TxType.expense => '− ${formatAmount(v, lang)}',
  TxType.transfer => formatAmount(v, lang),
};
```

---

## 6. Components

### 6.1 Balance card (Home hero)

```
┌──────────────────────────────────────────┐  radius 24, padding 24
│ Ümumi balans                     👁       │  labelLarge, onBalanceCardVariant; eye toggles masking
│ 3 210,75 ₼                               │  amountHero, onBalanceCard
│                                          │
│ ┌─────────────────┐ ┌─────────────────┐  │  two inner tiles, white 12 % overlay, radius 16
│ │ ↓ Gəlir         │ │ ↑ Xərc          │  │  labelMedium, onBalanceCardVariant
│ │ + 1 850,00 ₼    │ │ − 1 120,40 ₼    │  │  titleMedium tabular, balanceIncome / balanceExpense
│ └─────────────────┘ └─────────────────┘  │
│ Oktyabr 2026 ▾                           │  month switcher, bodySmall
└──────────────────────────────────────────┘
```
- Background: `LinearGradient(balanceCard → balanceCardEnd, topLeft → bottomRight)`.
- Masked state: the amounts become `••••• ₼`. The setting is persisted.
- Negative balance: the hero amount stays onBalanceCard and gets a "−" prefix plus a small
  `danger` pill reading "Mənfi balans".
- Loading: a shimmer block, 36dp high and 60 % wide, in a white 16 % overlay.

### 6.2 Transaction list tile

```
┌──────────────────────────────────────────────┐ min height 64, h-padding 16, v-padding 12
│ (●🍔)  Qida                     − 18,40 ₼     │ avatar 40 (category colour, white icon)
│        Kart · Bravo market          14:32    │ title titleMedium / subtitle bodyMedium onSurfaceVariant
└──────────────────────────────────────────────┘ amount amountTile in semantic colour; time bodySmall
```
- Title is the category name. Subtitle is account · note (one line, ellipsis).
- Transfer: the avatar is a `transferContainer` circle with a ⇄ icon in `transfer`; the title
  reads "Kart → Nağd".
- Grouped by day with a sticky header (titleSmall, onSurfaceVariant): "Bu gün", "Dünən",
  "12 oktyabr, B.e." The day net total sits on the right of the header.
- Swipe left reveals delete (`dangerContainer` background, confirmation snackbar with "Geri al").
  Tap opens edit.
- Pressed state uses the M3 ripple (onSurface at 10 %). Selected (multi-select) uses a
  primaryContainer background and a ✓ inside the avatar.

### 6.3 Category chip

- **Filter chip** (transaction filters): height 32, radius 8, a 12dp colour dot plus the label
  (labelMedium). Unselected: outline border, onSurfaceVariant text. Selected:
  `secondaryContainer` fill, ✓ leading, no border.
- **Picker tile** (add-transaction category grid): 4-column grid, 72×80. A 48dp colour circle
  with a white icon, label bodySmall below it (2 lines max, centred). Selected: a 3dp ring in
  `primary` with a 2dp gap.
- Type chips (Gəlir/Xərc/Transfer) use the corresponding container/on-container pair when
  selected.

### 6.4 Budget progress bar

```
Qida                                    82 %  ⚠
████████████████████████████░░░░░░░             height 8, radius 4, track surfaceContainerHighest
410,00 ₼ / 500,00 ₼            Qalıb: 90,00 ₼
```
- Row 1: category avatar (24) + name (titleMedium) + percentage (labelLarge in the state
  colour) + state icon (⚠ at warning, ⛔ at danger).
- Row 2: `LinearProgressIndicator`, value clamped to 1.0. Fill colour comes from the state rule
  in 2.2; in the normal state it is the category colour. Animate to the value over 600ms.
- Row 3: spent / limit (bodySmall onSurfaceVariant) on the left. On the right: remaining
  ("Qalıb: …") or, at danger, "Aşıb: 35,00 ₼" in `danger`.
- An optional "today" tick: a 2×12 marker in onSurfaceVariant at `dayOfMonth / daysInMonth`, so
  the user can see whether they are spending ahead of pace.
- Semantics: "Qida büdcəsi, 82 faiz istifadə olunub, xəbərdarlıq".

### 6.5 Amount input with numeric keypad

```
┌──────────────────────────────────────────┐
│ [ Xərc ][ Gəlir ][ Transfer ]            │ SegmentedButton, semantic container colours
│                                          │
│              − 18,40 ₼                   │ amountInput, semantic colour; blinking caret
│        Kart ▾        Qida ▾              │ account + category selectors (tonal buttons)
│  📅 Bu gün   📝 Qeyd əlavə et             │
├──────────────────────────────────────────┤
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐             │ keys 64 high, radius 16, surfaceContainerHigh
│  │ 1  │ │ 2  │ │ 3  │ │ ⌫  │             │ digits headlineSmall onSurface
│  ├────┤ ├────┤ ├────┤ ├────┤             │
│  │ 4  │ │ 5  │ │ 6  │ │ +  │             │ + − × ÷ allowed: simple calculator
│  ├────┤ ├────┤ ├────┤ ├────┤             │
│  │ 7  │ │ 8  │ │ 9  │ │ −  │             │
│  ├────┤ ├────┤ ├────┤ ├────┤             │
│  │ ,  │ │ 0  │ │ 00 │ │ ✓  │             │ ✓ = primary fill, onPrimary; "=" while an op is pending
│  └────┘ └────┘ └────┘ └────┘             │ gap 8
└──────────────────────────────────────────┘
```
- The decimal key shows `,` for az and `.` for en. At most 2 decimals, 10 integer digits.
- Do not open the system keyboard for the amount; the custom keypad is always visible.
- Haptic: `HapticFeedback.selectionClick()` on each key.
- Error state: an amount of 0 when Save is tapped makes the display shake (200ms) and shows
  "Məbləğ daxil edin" in `error` bodySmall.
- Long-press ⌫ clears everything.

### 6.6 Empty states

The layout is centred with 32 padding: an icon in a 96dp `primaryContainer` circle (48dp icon,
onPrimaryContainer), then a title (titleMedium), a body (bodyMedium onSurfaceVariant, max
280dp wide, centred), then an optional `FilledButton.tonal`.

| Screen | Title (az / en) | CTA |
|---|---|---|
| Transactions | "Hələ əməliyyat yoxdur" / "No transactions yet" | "Əməliyyat əlavə et" |
| Filtered list | "Uyğun nəticə tapılmadı" / "Nothing matches these filters" | "Filtrləri sıfırla" |
| Budgets | "Büdcə qurulmayıb" / "No budgets yet" | "Büdcə yarat" |
| Reports | "Bu dövr üçün məlumat yoxdur" / "No data for this period" | none |
| Accounts | "Hesab əlavə edin" / "Add your first account" | "Hesab əlavə et" |

### 6.7 PIN pad (lock screen)

```
            🔒 (app icon 64)
          Gəlir-Çıxar
        PIN kodu daxil edin          titleMedium
          ●  ●  ○  ○                 dots 14, gap 16; filled = primary, empty = 2dp outline ring

       ┌────┐  ┌────┐  ┌────┐
       │ 1  │  │ 2  │  │ 3  │        circular keys 72, surfaceContainerHigh, headlineMedium
       └────┘  └────┘  └────┘        gap 24 horizontal, 16 vertical
         4       5       6
         7       8       9
        [👆]     0      [⌫]          fingerprint key only when biometrics are enabled
```
- A 4-digit PIN (the setting allows 4 or 6).
- Wrong PIN: the dots turn `danger`, a 300ms horizontal shake, haptic `heavyImpact`, then the
  dots reset. After 5 failures the keys are disabled for 30s with a countdown in bodySmall.
- The biometric prompt opens automatically on screen load if enabled.
- `FLAG_SECURE` is set while the lock screen is shown, and also on the whole app if
  "Ekran görüntüsünü blokla" is on.
- Semantics: dots are announced as "2 / 4 rəqəm daxil edilib"; keys have labels.

### 6.8 Navigation and FAB

- `NavigationBar`, height 80, surfaceContainer, indicator primaryContainer. Icons are outlined
  when unselected and filled when selected. Labels are always shown.
  1. Ana səhifə / Home: `home`
  2. Əməliyyatlar / Transactions: `receipt_long`
  3. Hesabatlar / Reports: `pie_chart`
  4. Büdcələr / Budgets: `savings`
  5. Ayarlar / Settings: `settings`
- FAB: `FloatingActionButton.large` is not used; use the standard 56dp, radius 16, primary /
  onPrimary, icon `add`, tooltip "Əməliyyat əlavə et". It is visible on Home and Transactions
  and hidden on the other tabs. It opens Add Transaction as a full-screen route (slide up).
- Accounts, Categories and Export are reached from Settings (and Accounts also from the Home
  balance card).

---

## 7. Screens

All screens use a 16dp gutter and a large/medium top app bar that collapses on scroll.

### 7.1 Lock
See 6.7. Full-bleed surface, no app bar.

### 7.2 Ana səhifə (Home)
```
┌ Salam, Vaqif 👋                     🔔 ┐   greeting titleLarge
│ ┌ Balance card (6.1) ───────────────┐ │
│ └────────────────────────────────────┘ │
│ Hesablar                    Hamısı ›   │   horizontal scroll of account mini-cards 140×72
│ [Kart 2 100 ₼] [Nağd 310 ₼] [USD …]   │
│ Büdcə xülasəsi                         │   top 3 budgets nearest the limit (6.4, compact)
│ Son əməliyyatlar            Hamısı ›   │
│ tile · tile · tile · tile · tile       │   last 5 (6.2)
└────────────────────────────────────────┘
      [ nav bar ]                  (+) FAB
```

### 7.3 Əməliyyatlar (Transactions)
```
┌ Əməliyyatlar                 🔍  ⋮ ┐
│ ‹  Oktyabr 2026  ›                  │   month stepper
│ [Hamısı][Gəlir][Xərc][Transfer] →   │   type filter chips (scroll)
│ [Hesab ▾][Kateqoriya ▾][Tarix ▾]    │   dropdown filter chips; active ones shown filled
│ Gəlir +1 850 · Xərc −1 120 · Net    │   summary strip, bodySmall
│ ── Bu gün ─────────────── −42,40 ── │   sticky day header
│ tile … tile …                        │
└──────────────────────────────────────┘
```
The search icon expands into a search bar (note, amount, category). Filters open as a
bottom sheet on small screens.

### 7.4 Əməliyyat əlavə et / redaktə (Add/Edit)
A full-screen route. The app bar has ✕ (close) and, in edit mode, 🗑 (delete). The body follows
6.5. Category picker: a bottom sheet with the grid (6.3), "＋ Yeni kateqoriya" as the last cell.
Transfer mode replaces the category with "Haradan ▾ → Haraya ▾" account selectors. Save is the
✓ key; a "Saxla" FilledButton also appears in the app bar when the keyboard is hidden.

### 7.5 Hesablar (Accounts)
```
┌ ← Hesablar                      ＋ ┐
│ Ümumi: 3 210,75 ₼                  │  headlineSmall
│ ┌ (💳) Kart       Kapital Bank ┐  │  card per account: icon avatar, name, type
│ │                  2 100,00 ₼    │  │  balance right, amountTile
│ └────────────────────────────────┘  │
│ ┌ (💵) Nağd                 310 ₼ ┐ │
│ ┌ ($) USD əmanət   120,00 USD     ┐ │  + "≈ 204,00 ₼" bodySmall
│ Arxivlənmiş (2) ›                   │
└─────────────────────────────────────┘
```
Tap opens the account detail (balance plus a filtered transaction list). Long-press allows
reordering.

### 7.6 Kateqoriyalar (Categories)
A TabBar with [Xərc | Gəlir]. Below it is a list of tiles: colour avatar, name, a "12
əməliyyat" count, and a drag handle. "＋" opens an editor sheet with a name field, an icon
grid (Material icons) and a 12-swatch colour row (2.3) with the selected ring.

### 7.7 Hesabatlar (Reports)
```
┌ Hesabatlar                        ⤓ ┐  ⤓ opens Export
│ [Ay][Rüb][İl][Xüsusi]               │  SegmentedButton period
│ ‹ Oktyabr 2026 ›                     │
│ [ Xərc | Gəlir ]                    │  toggle for pie
│        ╭─────╮                       │  PieChart: donut, centreSpaceRadius 56,
│       (  1 120 ₼ )                   │  total in centre (titleLarge)
│        ╰─────╯                       │  touched slice radius +6, label shows %
│ ● Qida      410 ₼   36 %             │  legend list: dot, name, amount, % (sorted)
│ ● Nəqliyyat 220 ₼   20 %  …          │
│ Aylar üzrə                            │
│ ▇▅ ▇▃ ▆▆ ▇▄ ▅▅ ▇▆                    │  BarChart: last 6 months, grouped income/expense bars
│ May Iyn Iyl Avq Sen Okt               │  width 8, gap 4, radius top 4; grid outlineVariant dashed
│ Orta aylıq xərc: 1 045 ₼              │  insight line, bodyMedium
└──────────────────────────────────────┘
```
fl_chart: axis labels use bodySmall onSurfaceVariant; the tooltip background is
inverseSurface and its text onInverseSurface; there are no chart borders.

### 7.8 Büdcələr (Budgets)
```
┌ Büdcələr                          ＋ ┐
│ ‹ Oktyabr 2026 ›                     │
│ ┌ Ümumi büdcə ─────────────────────┐ │  overall card: spent/limit, big progress bar
│ │ 1 120 / 1 500 ₼        75 %      │ │
│ │ ████████████████░░░░░            │ │
│ │ Gündəlik limit: 29,30 ₼ (qalan 13 gün) │
│ └──────────────────────────────────┘ │
│ ⚠ 2 kateqoriya limitə yaxındır        │  warningContainer banner (if any)
│ 6.4 rows, sorted by % desc            │
└──────────────────────────────────────┘
```

### 7.9 İxrac (Export)
```
┌ ← İxrac                              ┐
│ Format     (•) CSV  ( ) Excel  ( ) PDF│  radio list tiles
│ Dövr       [Bu ay ▾]                  │
│ Hesablar   [Hamısı ▾]                 │
│ ☑ Kateqoriya xülasəsini daxil et      │
│                                       │
│ [        İxrac et  ⤓        ]         │  FilledButton, full width, bottom-pinned
│ Son ixraclar: gelir_cixar_2026-10.csv │
└───────────────────────────────────────┘
```
On success a snackbar offers "Paylaş" (share intent). The Backup/Restore (JSON) section uses
the same layout, separated by a divider.

### 7.10 Ayarlar (Settings)
Grouped `ListTile`s, with section headers in titleSmall primary:
- **Ümumi**: Dil (Azərbaycan / English), Əsas valyuta (AZN), Ayın başlanğıc günü, Tema
  (Sistem / Açıq / Tünd).
- **Təhlükəsizlik**: PIN kodu (switch → set PIN), Barmaq izi (switch), Avtomatik kilid (1 dəq ▾),
  Ekran görüntüsünü blokla.
- **Məlumat**: Hesablar ›, Kateqoriyalar ›, İxrac ›, Ehtiyat nüsxə ›, Bütün məlumatları sil
  (text in `danger`, followed by a confirmation dialog).
- **Haqqında**: Versiya.

---

## 8. Accessibility checklist

- Text contrast is ≥ 4.5:1 (see 2.4). Chart and category graphics are ≥ 3:1 (see 2.3).
- Income and expense are distinguished by sign + colour + arrow icon, never colour alone.
- Touch targets are ≥ 48dp. Keypad and PIN keys exceed that.
- Every icon-only button has a tooltip / semantic label in the active language.
- Layouts work at 200 % text scale: amounts are allowed to wrap below the title in tiles
  when `textScaler > 1.3`.
- Charts have a text legend with values, so the pie chart is never the only carrier of the data.
- Reduced motion: shake, progress and chart animations are disabled when
  `MediaQuery.disableAnimationsOf(context)` is true.

---
---

# v1.1: "More polished UI" + Kənar yerlər + auto rates

Date: 2026-10-28. Scope: motion, Home redesign, onboarding, Material You, holdings
("Kənar yerlər") and CBAR auto exchange rates. Everything in §1–§8 still applies unless a
section below overrides it.

## 9. Changelog and decisions

| # | Change | Why |
|---|---|---|
| 1 | Light `income` `#17763A → #146C35`, `expense` `#C0262D → #B42229` | With wallpaper colour, amounts can land on any surface role. At tone ≤ 40 they pass 4.5:1 down to tone 87 (surfaceDim), which holds for every hue. |
| 2 | Balance card end `#00797F → #006A6F` (light) and `#1E4A4E → #1C4649` (dark); `balanceExpense` `#FFC9C5 → #FFD6D2` (light) and `#FF8A84 → #FFA19B` (dark) | The v1.1 card carries 3 amounts across the whole card. Every on-card colour now passes AA on **both** gradient ends. |
| 3 | Inner tiles on the card use **black 16 %** (`balanceCardOverlay`) instead of white 12 % | A white overlay raised the background luminance and pushed labels to 2.5–3.9:1. Darkening can only increase contrast. |
| 4 | New `holding*` accent (violet) + `HoldingPlaceStyle` | Holdings need an identity distinct from money in/out (green/red), transfer (blue) and warning (amber). |
| 5 | Shared axis X for push/pop, fade through for tabs | Matches M3; neither needs the `animations` package. |
| 6 | 5 preset seeds + optional wallpaper colour; no green/red/amber presets | Those hues already carry meaning (income / expense / warning). |
| 7 | Holdings live **inside Home + Settings + Accounts**; no new tab (§14.1) | — |
| 8 | Error roles stay fixed in every scheme (`_withFixedError`) | Form errors and over-budget states must look identical whatever the wallpaper. |

---

## 10. New tokens (all in `lib/core/theme.dart`)

### 10.1 `AppColors` additions (optional constructor params, so v1.0 code compiles unchanged)

| Token | Light | Dark | Use | Contrast |
|---|---|---|---|---|
| holding | `#5B45B0` | `#C9BCFF` | Holding amounts and icons, "Kənarda" accents | L: 6.85 on surface, 5.69 on containerHighest · D: 10.71 / 7.14 |
| onHolding | `#FFFFFF` | `#25105F` | On a holding fill | 7.18 / 9.20 |
| holdingContainer / on | `#E7DEFF` / `#2A1A6B` | `#3B2F7A` / `#E7DEFF` | Holding chips, the account-link tag, tx avatar for account↔holding moves | 11.17 / 8.69 |
| balanceHolding | `#E2D9FF` | `#C9BCFF` | "Kənarda" amount on the balance card | 6.12 / 7.01 on start, 4.74 / 6.00 on end |
| balanceCardOverlay | `#000000` @ 16 % | same | Inner tiles on the card | Raises every on-card ratio (e.g. light balanceExpense 4.80 → 6.11) |
| success | `#146C35` | `#6FD892` | "Məzənnələr yeniləndi", "PIN quruldu" | = income |

### 10.2 Sizes / text styles / radius

| Token | Value | Use |
|---|---|---|
| `AppSizes.weekChartHeight` | 72 | Plot height of the Home weekly chart |
| `AppSizes.weekBarWidth` | 14 | Weekly bar width (top radius 4, `AppRadius.brBarTop`) |
| `AppSizes.holdingChartHeight` | 160 | Holding detail line chart |
| `AppSizes.onboardingIllustration` | 240 | Illustration box |
| `AppSizes.onboardingDot` / `onboardingDotActive` | 8 / 24 | Page indicator; the active one is a 24×8 pill |
| `AppSizes.seedSwatch` | 48 | Theme colour swatch |
| `AppSizes.holdingAvatar` | 40 | Place-type avatar |
| `AppSpacing.section` | 24 | Gap between Home cards |
| `AppTextStyles.amountSecondary` | 20/28 w600 tabular | "Kənarda", "Ümumi sərvət", holdings total |
| `AppTextStyles.amountDetail` | 32/40 w600 tabular | Holding detail headline |
| `AppTextStyles.onboardingTitle` | 28/36 w700 | Onboarding page titles |

---

## 11. Motion spec

Principle: motion explains **where things came from** and **that something changed**. It is
never decoration. Every duration goes through `AppMotion.of(context, d)` or
`AppMotion.reduced(context)`.

### 11.1 Tokens (`AppMotion`)

| Token | Duration | Curve | Used for |
|---|---|---|---|
| `page` | 300ms | `emphasized` (easeInOutCubicEmphasized) | Push/pop, shared axis X |
| `fadeThroughDuration` | 300ms | out: `exit` over 0–35 %, in: `enter` over 35–100 % | Tab switch, Home month switch, onboarding illustration swap |
| `countUp` | 800ms | `countUpCurve` (easeOutCubic) | Balance, net worth, holdings totals |
| `chartEntry` | 700ms | `chartCurve` (easeOutCubic) | First appearance of any chart |
| `chartUpdate` | 400ms | easeOutCubic | Period or filter change |
| `progress` | 600ms | easeOutCubic | Budget bars (unchanged from v1.0) |
| `listInsert` / `listRemove` | 300 / 200ms | `enter` / `exit` | AnimatedList size + fade (`AppMotion.listItem`) |
| `stagger` | 30ms per item, max 6 items | — | First load of lists and Home cards |
| `pressDown` / `pressUp` | 100 / 200ms | `standard` | Press scale feedback |
| `state` | 150ms | `standard` | Chips, toggles, PIN dots, seed swatch ring |
| `shake` | 300ms | 3 sine cycles, ±8dp | Wrong PIN (the invalid-amount shake stays 200ms, `short4`) |
| `onboardingPage` | 500ms | `emphasized` | `PageController.animateToPage` |
| Add-transaction route | 250ms | easeOutCubic slide-up | Unchanged (`_slideUp` in router.dart) |
| Bottom sheets | Flutter default (250 in / 200 out) | — | Unchanged |

### 11.2 Screen transitions
- **Push/pop** (Accounts, Categories, Holdings, Holding detail, Export, Exchange rates): shared
  axis X through `ThemeData.pageTransitionsTheme = AppTheme.pageTransitions`, so every
  `MaterialPage`/`MaterialPageRoute` gets it for free. The incoming page slides 30dp in from
  the end and fades in over 30–100 %. The outgoing page slides 30dp toward the start and fades
  out over 0–30 %. Pop is the exact reverse. A go_router `CustomTransitionPage` can call
  `AppMotion.sharedAxisX` directly.
- **Bottom tabs**: fade through. In `AppShell`, wrap the branch body as
  `AnimatedSwitcher(duration: AppMotion.of(ctx, AppMotion.fadeThroughDuration), transitionBuilder: AppMotion.fadeThrough, child: KeyedSubtree(key: ValueKey(index), child: ...))`.
  If that conflicts with keeping branch state in `StatefulNavigationShell`, use
  `navigatorContainerBuilder` with an `IndexedStack`, and animate only the newly selected
  child (opacity + scale 0.92 → 1).
- **Onboarding → app**: `AppFadeThroughPageTransitionsBuilder` (or `AppMotion.fadeThroughRoute`).

### 11.3 Count-up numbers
- Use `TweenAnimationBuilder<double>(tween: Tween(begin: previous, end: value))` with `countUp`
  (800ms) and `countUpCurve`. Count up from 0 only on the first build after a cold start;
  after that, animate from the previous value to the new one (for example after saving a
  transaction).
- Format every frame with `Fmt`. Tabular figures keep the width stable, so there is no
  jitter. Round to minor units.
- Masked balance (`••••• ₼`): no animation. Reduced motion: show the final value at once.
- Semantics: the label carries the **final** value only
  (`Semantics(label: finalText, excludeSemantics: true)`), so screen readers never read
  intermediate numbers.

### 11.4 Charts animate in
- fl_chart: pass `duration: AppMotion.of(ctx, AppMotion.chartEntry)` and `curve: chartCurve`.
  Build the first frame with zero values (bars `toY: 0`, line spots at the minimum, pie
  sections equal), then set the real data in `addPostFrameCallback`.
- Weekly bars grow from the baseline, left → right, staggered 30ms per bar.
- Holding line chart: the line draws while the area fill fades from 0 to 1.
- Reports donut: sweeps from 12 o'clock.
- Later data changes use `chartUpdate` (400ms) with no stagger.

### 11.5 Press feedback and haptics (`AppHaptics`)
| Element | Visual | Haptic |
|---|---|---|
| Amount keypad key | Ripple + scale `pressScaleKey` 0.92 (`pressDown` / `pressUp`) | `key()` = selectionClick |
| Keypad ✓ when the save succeeds | — | `confirm()` = mediumImpact |
| Keypad, invalid amount | 200ms shake | `error()` = heavyImpact |
| PIN digit | Key scale 0.92; the dot fills with a 150ms scale 0 → 1 | `pinDigit()` = lightImpact |
| Wrong PIN | Dots turn danger, 300ms shake | `error()` |
| Correct PIN | Dots flash primary, then fade through into the app | `confirm()` |
| Long-press ⌫ (clear) | — | `longPress()` |
| Cards and tiles (balance card, Home cards, holding tiles) | Scale `pressScaleCard` 0.97 + M3 ripple | none |
| Chips, segments, seed swatches, switches | 150ms colour change (`state`) | `key()` |
| Pull-to-refresh crossing its threshold | — | `confirm()`, once |

Reduced motion does **not** turn off haptics. Android's "touch feedback" setting controls
them.

### 11.6 Animated lists
- Transactions, the Home recent list, the holdings list and holding history use
  `SliverAnimatedList` / `AnimatedList` with `AppMotion.listItem` (size + fade, aligned to the
  top).
- Insert: 300ms, `enter`. Remove: 200ms, `exit`. Swipe-to-delete removes the item with the
  remove animation; "Geri al" re-inserts it with the insert animation.
- First load: items fade in and rise 8dp, staggered 30ms, for the first 6 items only.

### 11.7 Reduced motion (`MediaQuery.disableAnimationsOf`)
| Animation | With reduced motion |
|---|---|
| Page and tab transitions | Instant: the builders return the child unchanged |
| Count-up, chart entry, progress | Final value, no tween |
| Shake | None: the dots turn danger and the error text shows |
| Stagger, list insert/remove | Instant |
| Press scale | None. The ripple stays, because it is a state indicator |
| Onboarding page change | `jumpToPage` |

---

## 12. Material You (theme colour)

### 12.1 Settings → Ümumi → "Görünüş / Appearance"
```
┌ ← Görünüş                                  ┐
│ Tema           [Sistem][Açıq][Tünd]        │  SegmentedButton (v1.0 setting moved here)
│                                            │
│ Divar kağızı rəngi              [  ●  ]    │  SwitchListTile, only on Android 12+
│ Android 12+ divar kağızından rəng götürür  │  subtitle bodySmall
│                                            │
│ Rəng seçin                                 │
│  (◉)  ( )  ( )  ( )  ( )                   │  5 swatches 48dp, gap 12, Wrap
│ Firuzəyi Dəniz İndiqo Gavalı Qrafit        │  labelSmall under each
│                                            │
│ ┌ Önizləmə ────────────────────────────┐   │  mini balance card + one tx tile +
│ │ 3 210,75 ₼   + 250 ₼   − 18,40 ₼     │   │  a filled button, built live from
│ └──────────────────────────────────────┘   │  AppTheme.build(...) inside a Theme()
└────────────────────────────────────────────┘
```
- Swatch: a circle filled with that seed's light primary (`AppTheme.scheme(b, seed: s).primary`).
  When selected it gets a 3dp `onSurface` ring with a 3dp gap and a ✓ in `onPrimary`.
  Semantics: "Firuzəyi, seçilib".
- While "Divar kağızı rəngi" is on, the swatches are disabled (38 % opacity) and a caption
  reads "Divar kağızı rəngi aktivdir". The chosen preset is remembered for when the switch is
  turned off again.
- The theme change animates through `ThemeData.lerp` (MaterialApp default, 200ms).
  `AppColors.lerp` covers the extension.
- Persist `seedId` (`AppSeed.id`) and `useDynamicColor` (bool). Defaults: `teal`, `false`.

### 12.2 Presets (`AppSeed`)
| id | az / en | Seed | Scheme |
|---|---|---|---|
| `teal` (default) | Firuzəyi / Teal | `#00696E` | Hand-tuned v1.0 scheme and card |
| `ocean` | Dəniz / Ocean | `#1F5FA8` | `ColorScheme.fromSeed` |
| `indigo` | İndiqo / Indigo | `#4A4FB0` | fromSeed |
| `plum` | Gavalı / Plum | `#7B3F8A` | fromSeed |
| `graphite` | Qrafit / Graphite | `#4F5B66` | fromSeed, low chroma |

Green, red and amber seeds are left out on purpose. Ocean is close to the `transfer` blue, but
transfers always carry the ⇄ icon and are never shown as primary-coloured text.

### 12.3 Wiring (the builder agent adds `dynamic_color`)
```dart
DynamicColorBuilder(builder: (ColorScheme? lightDyn, ColorScheme? darkDyn) {
  final AppSeed seed = AppSeed.fromId(settings.seedId);
  final bool dyn = settings.useDynamicColor;
  return MaterialApp.router(
    theme: AppTheme.build(Brightness.light,
        seed: seed, dynamicScheme: dyn ? lightDyn : null),
    darkTheme: AppTheme.build(Brightness.dark,
        seed: seed, dynamicScheme: dyn ? darkDyn : null),
    themeMode: settings.themeMode,
    // ...
  );
});
```
A null `lightDyn` (Android < 12, desktop) means the switch is hidden and the seed is used. By
default the wallpaper scheme is **re-derived** with `ColorScheme.fromSeed(dyn.primary)`
(`rederiveDynamic: true`). dynamic_color builds its schemes from a CorePalette and can leave
the `surfaceContainer*` roles unset; re-deriving keeps the wallpaper hue and makes every M3
role consistent.

### 12.4 Semantic colours stay fixed: the derivation rule
WCAG contrast depends only on **relative luminance**. In M3 each surface role has a fixed HCT
*tone*, whatever the hue. A colour that passes against the worst tone therefore passes on
every seed and every wallpaper.

| Theme | Surface roles that can hold amounts | Tone range | Worst-case Y |
|---|---|---|---|
| Light | surface, containerLowest … containerHighest (and surfaceDim) | 100 … 87 | 0.700 |
| Dark | surface, containerLowest … containerHighest, surfaceBright | 4 … 24 | 0.041 |

**Rule:**
- Light theme: semantic text colours have tone ≤ 40 (Y ≤ 0.114). That gives at least 4.57:1
  on tone 87.
- Dark theme: semantic text colours have tone ≥ 70 (Y ≥ 0.408). That gives at least 5.03:1 on
  tone 24.
- Containers (`incomeContainer` etc.) are fixed pairs with their own on-colour, so they never
  depend on the scheme.

To derive a new semantic colour, pick the hue, then set its HCT tone to 40 (light) or 80
(dark), and check it with `AppContrast.ratio`.

Measured on neutral tones (every hue gives the same numbers):

**Light**

| Text | Tone | on 100 | on 94 | on 90 | on 87 |
|---|---|---|---|---|---|
| income `#146C35` | 39.8 | 6.51 | 5.60 | 5.04 | 4.65 |
| expense `#B42229` | 39.6 | 6.56 | 5.64 | 5.08 | 4.69 |
| transfer `#2F5D8A` | 38.3 | 6.88 | 5.91 | 5.33 | 4.91 |
| warning `#8A5300` | 40.6 | 6.33 | 5.44 | 4.90 | 4.52 |
| danger `#B3261E` | 39.7 | 6.54 | 5.62 | 5.06 | 4.67 |
| holding `#5B45B0` | 37.1 | 7.18 | 6.18 | 5.56 | 5.13 |

**Dark**

| Text | Tone | on 4 | on 12 | on 22 | on 24 |
|---|---|---|---|---|---|
| income `#6FD892` | 78.8 | 10.94 | 9.30 | 7.00 | 6.55 |
| expense `#FF8A84` | 70.2 | 8.47 | 7.20 | 5.41 | 5.07 |
| transfer `#9DC4EE` | 77.8 | 10.62 | 9.03 | 6.79 | 6.35 |
| warning `#FFB547` | 78.9 | 10.98 | 9.33 | 7.02 | 6.57 |
| danger `#FFB4AB` | 80.1 | 11.36 | 9.65 | 7.26 | 6.80 |
| holding `#C9BCFF` | 79.4 | 11.13 | 9.46 | 7.12 | 6.66 |

The old v1.0 light income `#17763A` measured 4.41 on tone 90, which fails AA. That is why it
changed.

**Runtime safety net:** `AppColors.resolve(scheme)` passes every semantic text colour through
`AppContrast.ensure(c, surfaces)`. If a scheme has non-standard surfaces (for example a raw
dynamic scheme with `rederiveDynamic: false`), it nudges **only the HSL lightness** until the
colour reaches 4.5:1 on all six surface roles. The hue stays the same, so "green = income"
still holds. With standard M3 tones it changes nothing.

**Rule for category colours (graphics, 3:1):**
- The categorical palette reaches ≥ 3:1 only on light tones ≥ 94 and dark tones ≤ 12, which
  means `surface … surfaceContainer`.
- Category avatars, pie slices and place-type avatars belong on those roles, never on
  `surfaceContainerHigh/Highest`. Worst cases on those roles: orange 2.92 on light tone 92,
  violet 2.90 on dark tone 17.
- Inputs and keypad keys use `High` and never hold a category colour.

### 12.5 Balance card under any scheme
- **Teal (default) with no wallpaper colour:** the hand-tuned constants (`AppColors.light/dark`).
- **Any other scheme:** `resolve()` builds the gradient from **the scheme's primary hue** at a
  fixed luminance:
  - Light: start Y 0.060 → end Y 0.100, saturation 0.30–0.90.
  - Dark: start Y 0.022 → end Y 0.045, saturation 0.15–0.45.
  - `onBalanceCardVariant` uses the same hue at Y 0.72 (dark: Y 0.50).
  - `onBalanceCard` is white (dark: tinted, Y 0.78).
- Because the card luminance is fixed, the fixed on-card colours keep a guaranteed minimum
  contrast:

| On card (against the lighter end) | Light (Y 0.100) | Dark (Y 0.045) |
|---|---|---|
| onBalanceCard | 7.00 | 8.64 |
| onBalanceCardVariant | 5.13 | 5.26 |
| balanceIncome | 5.51 | 6.27 |
| balanceExpense | 5.27 | 5.70 |
| balanceHolding | 5.20 | 6.38 |

`AppContrast.ensure` runs on the on-card colours as a second guard.

---

## 13. Home (redesigned)

### 13.1 Layout
```
┌──────────────────────────────────────────────┐
│ Sabahınız xeyir                              │  greeting titleLarge onSurface (large app bar,
│ Çərşənbə, 28 oktyabr                         │  collapses) + date bodyMedium onSurfaceVariant
│ ┌ Balance card (13.2) ──────────────────────┐ │
│ └───────────────────────────────────────────┘ │
│ ┌ Bu həftə ──────────────────── 312,40 ₼ ──┐ │  13.3 weekly spending
│ │  ▂   ▅   ▃   ▇   ▁   ▄   █               │ │
│ │  Ç   C.a C   Ş   B   B.e Ç.a             │ │  last 7 days, today on the right
│ └───────────────────────────────────────────┘ │
│ ┌ Büdcə ─────────────── Hamısı › ──────────┐ │  13.4 budget summary
│ └───────────────────────────────────────────┘ │
│ ┌ Kənar yerlər ──────── Hamısı › ──────────┐ │  13.5 holdings card
│ └───────────────────────────────────────────┘ │
│ Hesablar                          Hamısı ›   │  v1.0 account strip (unchanged)
│ Son əməliyyatlar                  Hamısı ›   │  last 5, animated list
│ tile · tile · tile · tile · tile             │
└──────────────────────────────────────────────┘
       [ nav bar ]                      (+) FAB
```
- Cards use `surfaceContainerLow`, radius 16, padding 16, with `AppSpacing.section` (24)
  between them. Tappable cards get the 0.97 press scale.
- On first load the cards stagger in, 30ms apart.
- The card order is fixed and the empty states are compact (one line plus a text button), so
  the layout never jumps.
- `RefreshIndicator` wraps the `CustomScrollView` (13.7).

### 13.2 Balance card v1.1
```
┌──────────────────────────────────────────────┐  radius 24, padding 20, gradient
│ Xərclənə bilən balans                   👁    │  labelLarge onBalanceCardVariant
│ 3 210,75 ₼                                   │  amountHero onBalanceCard, count-up
│ ┌──────────────────┐ ┌──────────────────┐    │  tiles: balanceCardOverlay, radius 16
│ │ ↓ Gəlir          │ │ ↑ Xərc           │    │  labelMedium onBalanceCardVariant
│ │ + 1 850,00 ₼     │ │ − 1 120,40 ₼     │    │  titleMedium tabular balanceIncome/Expense
│ └──────────────────┘ └──────────────────┘    │
│ ─────────────────────────────────────────    │  1dp divider, onBalanceCard @ 16 %
│ ▣ Kənarda                     4 500,00 ₼  ›  │  bodyMedium variant + amountSecondary balanceHolding
│ Σ Ümumi sərvət                7 710,75 ₼     │  bodyMedium variant + amountSecondary onBalanceCard
│ Oktyabr 2026 ▾                               │  month switcher (fade through on change)
└──────────────────────────────────────────────┘
```
- **Xərclənə bilən balans** (spendable) is the sum of account balances, the same total as in
  v1.0.
- **Kənarda** is the sum of all holdings, converted to AZN.
- **Ümumi sərvət** (net worth) is spendable + Kənarda. Only the month tiles depend on the
  month switcher; the three totals are always "now".
- The "Kənarda" row is a 48dp-high InkWell that opens the Holdings list.
- With no holdings, the row reads "Kənar yer əlavə et ›" in `onBalanceCardVariant` and the
  net-worth row is hidden, because it would just repeat the balance.
- A foreign-currency holding with no rate gets "≈" before the total and an ⓘ icon. Tapping the
  icon shows the snackbar "Bəzi məzənnələr yoxdur".
- The eye toggle masks **all three** totals and the month tiles.
- Semantics: one merged node per row, e.g. "Kənarda, 4500 manat, düymə".
- Loading: three shimmer bars (36 / 20 / 20dp high) at 16 % `onBalanceCard`.
- Negative spendable balance: the v1.0 danger pill.

### 13.3 Weekly spending mini chart
- Covers the last 7 days ending today (not the calendar week). Each bar is that day's expense
  in AZN, in the `expense` colour, 14 wide with `brBarTop`. A day with no spending shows a
  2dp stub in `outlineVariant`.
- Today's label is labelSmall **bold onSurface**; the other day labels are labelSmall
  onSurfaceVariant. Day abbreviations come from the locale (az: `B.e, Ç.a, Ç, C.a, C, Ş, B`;
  en: `Mo Tu We Th Fr Sa Su`).
- Header: "Bu həftə" (titleMedium) with the 7-day total right-aligned (amountTile, onSurface).
- Subtitle: "Keçən həftədən 12 % az" (bodySmall). It is `income`-coloured when spending is
  lower and `expense`-coloured when higher, and the word az/çox always says which, so colour
  is never the only cue.
- Tapping a bar shows a tooltip (inverseSurface) like "Çərşənbə · 42,40 ₼". Tapping the card
  opens Reports with "Xərc" selected and a 7-day period.
- No axes and no grid. Plot height is 72. Animation follows §11.4.
- Semantics: a hidden list such as "Bazar ertəsi 18 manat, …".

### 13.4 Budget summary card
- With an overall budget: one row "1 120 / 1 500 ₼ · 75 %", a progress bar coloured by the
  6.4 rules, and "Gündəlik limit 29,30 ₼". Below that, the top 2 categories at ≥ 80 %, as
  compact 6.4 rows with 24dp avatars.
- With only category budgets: the top 3 categories by %, as in v1.0.
- With no budgets: "Büdcə qurulmayıb" (bodyMedium) and a TextButton "Büdcə yarat".

### 13.5 Holdings card
```
┌ ▣ Kənar yerlər                   Hamısı › ┐
│ 4 500,00 ₼                                │  amountSecondary, holding colour
│ (🏠) Evdə nağd              1 200,00 ₼    │  top 3 by AZN value, compact 48dp rows,
│ (🏦) Kapital əmanət         3 000,00 ₼    │  32dp place-type avatars
│ (💎) Qızıl                     300,00 ₼   │
│ ⏰ Əmanətin müddəti 12 gün sonra bitir     │  optional warningContainer pill
└───────────────────────────────────────────┘
```
Empty state: "Evdə, yaxınlarda və ya əmanətdə saxladığınız pulu izləyin" with an "Əlavə et"
button.

### 13.6 Greeting
| Local time | az | en |
|---|---|---|
| 05:00–11:59 | Sabahınız xeyir | Good morning |
| 12:00–17:59 | Günortanız xeyir | Good afternoon |
| 18:00–22:59 | Axşamınız xeyir | Good evening |
| 23:00–04:59 | Salam | Hello |

The greeting is recomputed when the app resumes. It has no name, because the app is offline
and has no profile. The date line uses `EEEE, d MMMM` in the active locale.

### 13.7 Pull to refresh
- `RefreshIndicator` uses `primary` on `surfaceContainerHigh` (the theme sets
  `refreshBackgroundColor`). It invalidates the Home providers and, **when auto rates are
  on**, also starts the CBAR refresh and awaits it (with an 8s timeout).
- A snackbar reports the result, and only when a rate refresh was attempted: "Məzənnələr
  yeniləndi · 09:41", or "Oflayn: son məzənnələr istifadə olunur (27 okt)".
- With auto rates off, the pull only rebuilds and shows no snackbar.

---

## 14. Kənar yerlər (holdings)

### 14.1 Navigation recommendation
**Keep 5 tabs.** Holdings get three entry points instead: Home (the balance-card row and the
holdings card), Settings → Məlumat → "Kənar yerlər", and a link at the bottom of Accounts.

Why:
- **Frequency.** Tabs are for daily tasks: logging, reviewing, budgeting. Holdings change a
  few times a month.
- **A 6th tab is too many.** M3 allows 3–5 destinations. A sixth squeezes the Azerbaijani
  labels below 64dp, and "Əməliyyatlar" already truncates.
- **Every existing tab is in use.** Reports and Budgets are both weekly destinations, and
  Settings holds security, PIN and backup. Replacing any of them costs more than holdings
  gain.
- **The entry point sits next to the number it explains.** Users meet holdings through the
  "Kənarda" and "Ümumi sərvət" rows on Home. Settings and Accounts cover the "where do I
  manage my money places" path.

Implementation notes:
- Routes `/holdings` and `/holdings/:id`, pushed with shared axis.
- The FAB stays hidden on these screens; the list has its own "＋" in the app bar.
- Revisit if analytics show holdings opened more than 3× a week. The fallback is a "Pul /
  Money" tab with segments [Hesablar | Kənar yerlər]. It would hold Accounts plus Holdings,
  so it should replace nothing; if the bar must stay at 5, Budgets would move into Reports.

### 14.2 Place types (`HoldingPlaceStyle`, keyed by `HoldingPlace.name`)
| name | az / en | Icon | Palette # | Order |
|---|---|---|---|---|
| homeCash | Evdə nağd / Cash at home | `cottage_outlined` | 9 olive | 0 |
| person | Yaxın adamda / With a person | `person_outline` | 4 violet | 1 |
| bankDeposit | Bank əmanəti / Bank deposit | `account_balance_outlined` | 0 blue | 2 |
| gold | Qızıl, qiymətli əşya / Gold and valuables | `diamond_outlined` | 6 mustard | 3 |
| other | Digər / Other | `inventory_2_outlined` | 7 slate | 4 |

- Avatar: a 40dp circle in the palette colour with a white icon, the same rule as categories
  (§2.3).
- The feature icon is `HoldingPlaceStyle.featureIcon`.
- Usage: `HoldingPlaceStyle.forPlace(holding.place)`.

### 14.3 List screen `/holdings`
```
┌ ← Kənar yerlər                          ＋ ┐  medium app bar
│ Cəmi                                       │  labelLarge onSurfaceVariant
│ 4 500,00 ₼                                 │  headlineSmall tabular, holding colour, count-up
│ Ümumi sərvətin 58 %-i · 5 yer              │  bodySmall onSurfaceVariant
│ ▬▬▬▬▬▬ ▬▬▬▬▬▬▬▬▬▬▬▬ ▬▬                     │  8dp stacked bar by place type, 2dp gaps
│                                            │
│ EVDƏ NAĞD                     1 200,00 ₼   │  group header titleSmall + group total
│ ┌──────────────────────────────────────┐   │  surfaceContainerLow group, radius 12
│ │ (🏠) Sandıq          1 000,00 ₼      │   │  tile 64: name / "3 gün əvvəl yeniləndi"
│ │      3 gün əvvəl yeniləndi           │   │
│ │ (🏠) Dollar zərfi      100,00 USD    │   │  foreign currency: its own code +
│ │      ≈ 170,00 ₼                      │   │  "≈ 170,00 ₼" in bodySmall
│ └──────────────────────────────────────┘   │
│ BANK ƏMANƏTİ                  3 000,00 ₼   │
│ │ (🏦) Kapital 12 ay   3 000,00 ₼      │   │  deposit subtitle: "11 % · 135 gün qalıb"
│ │      11 % · 135 gün qalıb    [⏰]    │   │  + pill when ≤ 30 days or matured
│ YAXIN ADAMDA …                             │
└────────────────────────────────────────────┘
```
- Groups follow `order`, and empty groups are hidden. Within a group, tiles are sorted by AZN
  value, highest first.
- Tile amounts are `amountTile` in `onSurface`. Holdings are neither income nor expense, so
  they get no sign colour. Only the headline total uses `holding`.
- Stacked bar segments use the place-type colours. Semantics: "Evdə nağd 27 %, Bank əmanəti
  67 %, …".
- Tap opens the detail screen. Long-press opens a menu: Düzəliş et / Məbləği dəyiş / Sil.
- Delete asks first: "«Sandıq» silinsin? Tarixçə də silinəcək." After deleting, a snackbar
  offers "Geri al".
- Holdings with a zero value and no change for 90 days collapse into "Sıfır qalıqlılar (2) ›".
- Empty state: a 96dp `holdingContainer` circle with `featureIcon`, then:
  - Title: "Kənar yer yoxdur".
  - Body: "Evdəki nağd pulu, yaxınınızdakı pulu, əmanəti və qızılı burada izləyin. Xərclənə
    bilən balansa daxil olmur, ümumi sərvətə daxildir."
  - CTA: "Kənar yer əlavə et".

### 14.4 Detail screen `/holdings/:id`
```
┌ ← Kapital 12 ay                     ✎  ⋮ ┐  ✎ = edit sheet, ⋮ = delete
│ [🏦 Bank əmanəti]                         │  place-type chip (holdingContainer)
│ 3 000,00 ₼                                │  amountDetail onSurface, count-up
│ ≈ 1 764,71 USD                            │  foreign currency only: the AZN equivalent
│ ┌ Əmanət ────────────────────────────────┐ │  bankDeposit only, when either field is set
│ │ Faiz          11 %                     │ │  labelMedium / titleMedium, 2 columns
│ │ Bitmə tarixi  12 mart 2027 · 135 gün   │ │
│ │ Təxmini gəlir ≈ 122,05 ₼               │ │  simple interest to maturity, "təxmini"
│ └────────────────────────────────────────┘ │
│ [3A] [6A] [1İ] [Hamısı]                    │  SegmentedButton period, default 1İ
│  ╭──────╮____╱‾‾‾‾                        │  LineChart 160dp, step line
│ ─────────────────────────                  │  colour = place-type colour, width 2.5
│ Okt        Dek        Fev                  │  area: colour 24 % → 0 % vertical gradient
│                                            │
│ [ ＋ Əlavə et ] [ − Götür ] [ = Dəyər ]     │  3 equal FilledButton.tonal, 48dp
│                                            │
│ Tarixçə                                    │  titleMedium
│ ── Oktyabr 2026 ────────────────────────── │  sticky month header
│ (＋) Əlavə edildi          + 500,00 ₼      │  history tile 56, 32dp kind avatar in
│      12 okt · Kartdan · "bonus"            │  holdingContainer / onHoldingContainer
│ (=) Dəyər yeniləndi       3 000,00 ₼       │  setValue: unsigned; "əvvəl 2 950,00" bodySmall
│ (−) Götürüldü              − 200,00 ₼      │
└────────────────────────────────────────────┘
```
- History amounts are shown in `onSurface` with a "+" or "−" sign character (add / withdraw).
  Green and red are **not** used: moving your own money is neither income nor expense.
- A "Kartdan / Karta" chip appears when the entry is linked to an account move
  (`TxType.toHolding` / `fromHolding`). Tapping it opens that transaction.
- Chart: the step line comes from `HoldingMath.replay`, plus a final point at today. Touching
  it shows a tooltip like "12 okt · 3 000,00 ₼". The Y axis shows only compact min/max labels
  (bodySmall).
- With a single point, the chart draws one dot and the caption "Qrafik üçün ən azı 2 qeyd
  lazımdır".
- Deposit pill:
  - more than 30 days left: no pill;
  - 30 days or fewer: `warningContainer` "⏰ 12 gün qalıb";
  - matured: `dangerContainer` "Müddəti bitib", with a "Dəyəri yenilə" action.
- Tapping a history entry opens a sheet to edit its note or date, or delete it. If the change
  would make the value negative at any point, the data layer throws
  `HoldingAmountFailure.negative`, and the sheet shows "Bu dəyişiklik qalığı mənfi edər".

### 14.5 Add / edit sheet (modal bottom sheet, scroll-controlled, up to 90 % height)
```
┌ ─── (drag) ─────────────────────────────────┐
│ Yeni kənar yer                       [Saxla] │  titleLarge + FilledButton, disabled until valid
│ Yer növü                                     │
│ [🏠 Evdə] [👤 Adamda] [🏦 Əmanət]             │  ChoiceChips with icons, Wrap
│ [💎 Qızıl] [▢ Digər]                          │
│ Ad            [ Sandıq                     ] │  hint per type: "Məs: Anamda", "Məs: Kapital 12 ay"
│ Valyuta [ AZN ▾ ]   Məbləğ [ 1 000,00      ] │  decimal keyboard, az uses ","
│ ── only for Əmanət ───────────────────────── │  appears with AnimatedSize 250ms
│ Faiz (%)      [ 11      ]      (istəyə görə) │
│ Bitmə tarixi  [ 12.03.2027  📅 ] (istəyə görə)│  date picker
│ Qeyd          [                            ] │  maxLines 3
│ ☐ Məbləği hesabdan köçür     [Kart ▾]        │  new holdings only: creates TxType.toHolding
└──────────────────────────────────────────────┘
```
- Validation:
  - name: 1–40 characters;
  - amount ≥ 0 (zero is allowed, e.g. a placeholder for a new deposit);
  - interest: 0–100 with at most 2 decimals;
  - maturity date: after today.
- Edit mode:
  - The title is "Düzəliş et".
  - The amount field is **hidden**: amounts change only through 14.6, which keeps the
    history honest.
  - Currency is locked once entries exist (`currencyLocked`). The field shows disabled, with
    the helper text "Tarixçə olduğu üçün valyuta dəyişmir".
- The initial amount is stored as the first `setValue` entry.

### 14.6 "Adjust amount" sheet
```
┌ ─── (drag) ─────────────────────────────────┐
│ Kapital 12 ay · indiki 3 000,00 ₼            │  titleMedium + bodySmall
│ [ ＋ Əlavə et ][ − Götür ][ = Dəyəri yenilə ] │  SegmentedButton; opens on the tapped kind
│                + 500,00 ₼                    │  amountInput in onSurface, sign by kind
│      Yeni qalıq: 3 500,00 ₼                  │  live preview bodyMedium; danger if < 0
│ 📅 Bu gün    📝 Qeyd                          │
│ ☐ Hesabla əlaqələndir   [Kart ▾]             │  add → "Hesabdan" (toHolding),
│                                              │  withdraw → "Hesaba" (fromHolding)
│ ┌────┬────┬────┬────┐                        │  v1.0 keypad (6.5) without operators,
│ … keypad …                         [ ✓ ]     │  haptics per 11.5
└──────────────────────────────────────────────┘
```
- If a withdrawal is larger than the current value, the preview turns `danger` with "Qalıqdan
  çox götürmək olmaz", ✓ is disabled, and tapping it shakes the display.
- "Dəyəri yenilə" shows an unsigned amount, and the preview shows "Fərq: + 50,00 ₼". It cannot
  link to an account.
- With the account link on, the account balance changes too, and a transaction appears in the
  list (14.7). It is excluded from income/expense totals, budgets and reports, like
  transfers.
- When linked to a foreign-currency account, the account must have the holding's currency.
  Otherwise the account picker shows only matching accounts. The data layer decides the
  exact rule; the UI only filters.

### 14.7 Holding moves in the transactions list (`TxType.toHolding` / `fromHolding`)
- Avatar: a `holdingContainer` circle with the place-type icon in `onHoldingContainer`.
- Title: "Kart → Sandıq" or "Sandıq → Kart".
- Amount: unsigned, in `holding`.
- Filter: a "Kənar yer" type chip after "Transfer".
- The Add Transaction screen does not offer these types; they are created only from 14.5 and
  14.6. Tapping one opens the holding detail.

---

## 15. Onboarding (first launch)

Onboarding is shown once (`onboardingDone == false`), before the first-run PIN screen. It
replaces the v1.0 behaviour of going straight to PIN setup.

### 15.1 Flow
`Intro 1 → Intro 2 → Intro 3 → Dil → Valyuta → PIN (existing PinFlowScreen, setup) → Avtomatik məzənnə → App`

- **Skip on the intro pages:** "Keç" (top right) on pages 1–3 jumps straight to **Dil**.
  Language and rates still need a decision, but both have defaults.
- **Skip on the setup steps (Dil … Məzənnə):** "Keç" applies the defaults and finishes:
  language = device locale if it is az or en (otherwise az), PIN off, auto rates off.
- **PIN step:** "PIN qur" opens the existing flow; "Sonra" (TextButton) skips it. It can be
  turned on later in Settings.
- **Back:** system or predictive back goes to the previous page. On Intro 1 it leaves the app.
- **Finish:** set `onboardingDone = true`, then fade through into Home. Home's first count-up
  runs from 0.
- Existing v1.0 users upgrading are never shown onboarding: the builder sets
  `onboardingDone = true` when any account or transaction already exists.

### 15.2 Intro pages
```
┌──────────────────────────────────────┐
│                               Keç    │  TextButton
│                                      │
│          ╭───────────────╮           │  240dp illustration (15.3)
│          │   ◯  ▢  ₼     │           │
│          ╰───────────────╯           │
│                                      │
│   Gəlir və xərcini bir yerdə gör     │  onboardingTitle, centred, max width 320
│   Hər əməliyyatı saniyələr içində    │  bodyLarge onSurfaceVariant, centred
│   qeyd et. İnternet lazım deyil.     │
│                                      │
│              ━━  •  •                │  dots 8dp (onSurfaceVariant @ 38 %),
│                                      │  active one is a 24×8 primary pill
│ [            Davam et             ]  │  FilledButton, full width, 24 + safe-area bottom
└──────────────────────────────────────┘
```
| # | Title (az / en) | Body (az / en) |
|---|---|---|
| 1 | Gəlir və xərcini bir yerdə gör / See income and spending in one place | Hər əməliyyatı saniyələr içində qeyd et. İnternet lazım deyil. / Log every transaction in seconds. No internet needed. |
| 2 | Büdcə qur, limitdən xəbərdar ol / Set budgets, stay under the limit | Limitin 80 %-nə çatanda xəbərdarlıq edirik. / We warn you at 80 % of a limit. |
| 3 | Bütün sərvətini izlə / Track everything you own | Evdəki nağd pul, əmanət, qızıl: hamısı «Ümumi sərvət»də. / Cash at home, deposits, gold: all in your net worth. |

The PageView supports swiping; "Davam et" on page 3 goes to Dil.

### 15.3 Illustrations (code only: Containers, CustomPaint and Material icons; no image assets)
**Shared frame** for all three: a 240dp box with a 200dp `primaryContainer` circle in the
centre and 2–3 small floating shapes in `tertiaryContainer` / `secondaryContainer`. The
illustrations therefore follow the seed or the wallpaper.

1. **Ledger.**
   - A white rounded "phone": 120×168, radius 20, `surfaceContainerLowest`, elevation-1
     shadow.
   - Inside it, 3 fake tiles: 24dp circles in categorical colours 1 / 0 / 2 next to grey 8dp
     bars.
   - A floating "+" FAB (40dp, `primary`) at the bottom right.
   - An `incomeContainer` chip with ↓ and an `expenseContainer` chip with ↑ floating top left
     and top right.
2. **Budget.**
   - Three horizontal progress bars (160 wide, 10 high, radius 5), filled to 45 % in
     `primary`, 82 % in `warningFill` with a ⚠ icon, and 100 % in `danger` with ⛔.
   - Above them, a `savings` icon (48) in a `surfaceContainerLowest` circle.
3. **Net worth.**
   - Three rounded squares (64dp, radius 16) in the place-type colours (olive / blue /
     mustard) with white `cottage`, `account_balance` and `diamond` icons, fanned at
     −8° / 0° / +8°.
   - A "Σ" badge on top (32dp, `holding` fill, `onHolding` text).

**Motion:** on page enter, the main shape scales 0.9 → 1 and the floating shapes move 12dp →
0 with a 40ms stagger (`onboardingPage`, `enter`). While the user drags, the floating shapes
move at 1.3× the page offset, a light parallax. With reduced motion everything is static.

**Semantics:** illustrations are wrapped in `ExcludeSemantics`. The title carries the meaning.

### 15.4 Setup pages
A thin step bar sits at the top of all four setup pages: 4 segments, 4dp high, `primary` on
`surfaceContainerHighest`, with a "2 / 4" label in labelSmall. "Keç" stays at the top right.

```
Dil / Language                          Əsas valyuta
┌──────────────────────────────┐        ┌──────────────────────────────┐
│ ▬▬▬▬ ▭▭▭▭ ▭▭▭▭ ▭▭▭▭     1 / 4 │        │ ▬▬▬▬ ▬▬▬▬ ▭▭▭▭ ▭▭▭▭   2 / 4  │
│ Tətbiqin dili                │        │ Əsas valyuta                 │
│ (•) 🇦🇿  Azərbaycan dili      │        │ ┌ ₼  AZN                ✓ ┐ │  one card in the selected
│ ( ) 🇬🇧  English              │        │ │    Azərbaycan manatı    │ │  style, not interactive
│                              │        │ └─────────────────────────┘ │
│                              │        │ Bütün cəmlər AZN-də göstərilir.│ bodyMedium
│                              │        │ USD/EUR hesablar məzənnə ilə  │
│                              │        │ çevrilir.                     │
│ [         Davam et        ]  │        │ [         Davam et        ]  │
└──────────────────────────────┘        └──────────────────────────────┘

PIN                                     Avtomatik məzənnə
┌──────────────────────────────┐        ┌──────────────────────────────┐
│          ( 🔒 )               │        │          ( ⇅ ₼ )             │  96dp primaryContainer circle
│ Tətbiqi PIN ilə qoru         │        │ Məzənnələri avtomatik yenilə │  titleLarge
│ Telefonunuz başqasının        │        │ Mənbə: AMB (cbar.az). Yalnız │  bodyMedium
│ əlinə keçsə belə…            │        │ məzənnə yüklənir, heç bir     │
│                              │        │ məlumat göndərilmir.          │
│                              │        │ Avtomatik yenilə     [ ○ ]   │  SwitchListTile, default off
│ [         PIN qur         ]  │        │ [           Başla          ] │
│           Sonra              │        │                              │
└──────────────────────────────┘        └──────────────────────────────┘
```
- **Language:** 64dp `RadioListTile`s. The flags are text emoji, not assets. Selecting a
  language re-renders the page at once, with a fade through on the text.
- **Currency:** display only in v1.1, with no choice. Semantics: "Əsas valyuta: Azərbaycan
  manatı".
- **PIN:** after a successful setup, the page returns with a ✓ in `success` and the button
  becomes "Davam et".
- **Rates:** "Başla" saves the switch value. If it is on, the first fetch starts in the
  background; it never blocks entry.

---

## 16. Auto exchange rates (CBAR)

### 16.1 Settings group ("Məzənnələr" section)
```
│ MƏZƏNNƏLƏR                                   │  section header titleSmall primary
│ Avtomatik yenilə                     [  ●  ] │  SwitchListTile
│ Mənbə: AMB (cbar.az)                         │  subtitle bodySmall
│ ✓ Son yenilənmə: bu gün 09:41    [⟳ Yenilə]  │  status row (16.2) + TextButton.icon, 48dp
│ Məzənnələr                               ›   │  opens the rates screen (16.3)
```
- The status row and "Yenilə" appear only while the switch is on, with an AnimatedSize 250ms.
  "Məzənnələr ›" is always shown.
- The subtitle under "Məzənnələr ›" lists the rates, e.g. "USD 1,70 · EUR 1,95 · RUB 0,0185".

### 16.2 States
| State | Status row | Yenilə button | Extra |
|---|---|---|---|
| Success / idle | `check_circle` in `success`: "Son yenilənmə: bu gün 09:41" | enabled | — |
| Loading | 16dp `CircularProgressIndicator` (2dp stroke): "Yenilənir…" | disabled, label "Yenilənir" | `Semantics(liveRegion: true)` |
| Just updated | as success; the timestamp cross-fades (`state`) | enabled | snackbar "Məzənnələr yeniləndi" + `AppHaptics.confirm()` |
| Offline | `cloud_off` in `warning`: "Oflayn. Son məzənnələr: 27 okt 09:12" | enabled, label "Yenidən cəhd et" | the last rates stay in use |
| Error (bad or unparseable response) | `error_outline` in `danger`: "Yenilənmədi. Son məzənnələr: 27 okt" | enabled | details in a tooltip; the last rates stay |
| Never fetched + offline | `cloud_off`: "Hələ yüklənməyib. Əl ilə daxil edilən məzənnələr istifadə olunur." | enabled | — |
| Stale (older than 3 days) | as success, but the time is in `warning` with "(köhnəlib)" | enabled | — |

- Errors never block the UI and never clear the stored rates.
- Automatic refresh runs on app start and resume, at most once every 6 hours (CBAR publishes
  once a working day), and on the Home pull-to-refresh.

### 16.3 Rates screen with overrides (`ExchangeRatesScreen`)
```
┌ ← Məzənnələr                        [Saxla] ┐
│ 1 vahid = ? AZN · AMB, 28 okt 2026           │  bodySmall onSurfaceVariant
│ ┌──────────────────────────────────────────┐ │  surfaceContainerLow group
│ │ USD   1,7000          [AMB]       ✎      │ │  row 64: code titleMedium, value amountTile,
│ │ EUR   [ 1,9500     ]  [Əl ilə]    ✕      │ │  source chip, action icon (48dp)
│ │ RUB   0,0185          [AMB]       ✎      │ │
│ └──────────────────────────────────────────┘ │
│ ⓘ Əl ilə daxil edilən məzənnə avtomatik      │  bodySmall onSurfaceVariant
│   yenilənmədə dəyişmir.                      │
└──────────────────────────────────────────────┘
```
- Source chips: "AMB" uses `secondaryContainer`; "Əl ilə" (manual) uses `tertiaryContainer`.
  Both are labelSmall.
- ✎ turns the row into the inline v1.0 input field. Saving marks the rate as an override.
- ✕ "Sıfırla" removes the override, and the row returns to the CBAR value with the "AMB" chip.
  Tooltip: "AMB məzənnəsinə qaytar".
- With auto rates off, every rate is manual and no chips are shown (v1.0 behaviour).

---

## 17. Component specs and accessibility additions

### 17.1 New components (for `lib/core/widgets.dart` / feature widgets)
| Component | Spec |
|---|---|
| `PressScale` | `AnimatedScale(scale: pressed ? AppMotion.pressScaleCard : 1, duration: pressed ? pressDown : pressUp, curve: AppMotion.standard)`, driven by `onTapDown`/`onTapUp`/`onTapCancel`. Off under reduced motion. A `scale` param allows `pressScaleKey` for keys. |
| `CountUpAmount` | §11.3. Params: `value` (minor units), `currency`, `lang`, `style`, `masked`. |
| `MetricRow` | Balance-card row: 48dp InkWell, 20dp icon, label, right-aligned amount, optional chevron. |
| `WeekBars` | §13.3, built on fl_chart `BarChart` or a plain `Row` of `AnimatedContainer`s. |
| `PlaceAvatar` | `HoldingPlaceStyle.forPlace(p)`: 40dp (32 compact) circle in the palette colour, white icon. |
| `HoldingTile` | 64dp; avatar, name, subtitle (note / deposit info / "updated …"), `amountTile` with an optional "≈ AZN" line. |
| `HistoryTile` | 56dp; 32dp kind avatar (+ / − / =) in `holdingContainer`; signed `onSurface` amount; optional account chip. |
| `SeedSwatch` | 48dp circle; when selected, a 3dp `onSurface` ring with a 3dp gap and a ✓; 150ms ring animation. |
| `RateStatusRow` | §16.2 states, `liveRegion`. |
| `OnboardingDots` | 8dp dots; the active one is a 24×8 pill; width and colour animate over `state`. Semantics: "Səhifə 2 / 3". |
| `StepBar` | 4 segments, 4dp high, 4dp gap, `primary` / `surfaceContainerHighest`. |

### 17.2 Accessibility additions
- Spendable, Kənarda and Ümumi sərvət each have their own full spoken label. When masked they
  read "gizlədilib".
- Holding history amounts carry a "+" / "−" sign and a spoken kind ("Əlavə edildi, 500
  manat"). Colour is never the only cue.
- At 200 % text, balance-card rows wrap the amount under the label once `textScaler > 1.3`.
  On screens narrower than 360dp, the adjust-sheet segments drop their text and show icons
  with tooltips.
- Every new colour pair is listed with its ratio in §10.1, §12.4 and §12.5, and all of them
  pass AA (text 4.5:1, graphics 3:1).
- Touch targets: metric rows, swatches, chips and the rate actions are all ≥ 48dp.

### 17.3 New l10n keys (suggested names, for the builder)
- Home: `greetingMorning, greetingAfternoon, greetingEvening, greetingNight,
  spendableBalance, heldElsewhere, netWorth, addHoldingShort, thisWeek, vsLastWeekLess,
  vsLastWeekMore, someRatesMissing`.
- Holdings: `holdings, addHolding, editHolding, holdingPlaceHomeCash, holdingPlacePerson,
  holdingPlaceBankDeposit, holdingPlaceGold, holdingPlaceOther, holdingAdd, holdingWithdraw,
  holdingSetValue, holdingAdded, holdingWithdrawn, holdingValueSet, interestRate,
  maturityDate, daysLeft, matured, estimatedInterest, linkAccount, fromAccount, toAccount,
  newBalancePreview, difference, withdrawTooMuch, wouldGoNegative, currencyLocked,
  emptyHoldingsTitle, emptyHoldingsBody, zeroHoldings, holdingDeleteConfirm,
  chartNeedsTwoPoints`.
- Onboarding: `onboardingSkip, onboardingNext, onboardingStart, onb1Title, onb1Body,
  onb2Title, onb2Body, onb3Title, onb3Body, chooseLanguage, baseCurrency, baseCurrencyBody,
  protectWithPin, protectWithPinBody, setPin, later`.
- Rates: `autoRates, autoRatesSource, autoRatesBody, ratesLastUpdated, ratesUpdating,
  ratesUpdated, ratesOffline, ratesError, ratesNeverFetched, ratesStale, refresh, retry,
  rateSourceCbar, rateSourceManual, resetToCbar, manualOverrideNote`.
- Appearance: `appearance, themeColour, wallpaperColour, wallpaperColourBody,
  wallpaperColourActive, preview` (the seed names come from `AppSeed.label(lang)`).

### 17.4 Theme API summary (v1.1)
| API | Notes |
|---|---|
| `AppTheme.light` / `AppTheme.dark` | Unchanged: teal, hand-tuned |
| `AppTheme.build(Brightness, {AppSeed seed, ColorScheme? dynamicScheme, bool rederiveDynamic = true})` | Main entry point |
| `AppTheme.lightWith({...})` / `darkWith({...})` | Wrappers |
| `AppTheme.scheme(Brightness, {...})` | ColorScheme only (previews, swatches) |
| `AppTheme.pageTransitions` | Shared axis X for all platforms (already set inside the theme) |
| `AppSeed` enum: `id, color, labelAz, labelEn, label(lang), fromId(id), defaultSeed` | Persist `id` |
| `AppColors.resolve(ColorScheme)` | Fixed semantics + contrast guard + derived card |
| New `AppColors` fields: `holding, onHolding, holdingContainer, onHoldingContainer, balanceHolding, balanceCardOverlay, success` | Optional constructor params |
| `AppContrast.ratio / ensure / withLuminance` | WCAG utilities |
| `HoldingPlaceStyle.of(name) / forPlace(enum) / values / featureIcon`, `.icon`, `.color(c)`, `.order` | Keyed by `HoldingPlace.name` |
| `AppMotion` tokens + `of`, `reduced`, `staggerFor`, `sharedAxisX`, `fadeThrough`, `fadeThroughRoute`, `listItem` | §11 |
| `AppSharedAxisPageTransitionsBuilder`, `AppFadeThroughPageTransitionsBuilder` | Respect reduced motion |
| `AppHaptics.key / pinDigit / confirm / error / longPress` | §11.5 |
| `AppDurations` | Unchanged (fast / normal / slow) |
