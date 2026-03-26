<p align="center">
  <img src="assets/onebuttonpet-icon.png" alt="OneButtonPet icon" width="180" />
</p>

# OneButtonPet

- One button to toggle pet attack and follow on your current target
- Built for a simple `/pettoggle` macro or a direct addon keybind
- Keeps a short target memory so rapid double-taps still switch cleanly between attack and follow

Current version: `1.0.2`

## In Game

<p align="center">
  <img src="assets/macro-usage-screenshot.png" alt="OneButtonPet macro and keybind usage" width="700" />
</p>

Use one short macro:

```text
#showtooltip
/pettoggle
```

## Usage

- `/pettoggle`
- `/onebuttonpet`
- `/obp`
- `/pettoggle help`
- `/pettoggle status`
- Bind `Toggle Pet Attack/Follow` under `Key Bindings -> AddOns`

## Behavior

- First press on a hostile living target sends pet attack
- Second press on that same target toggles pet follow
- Friendly, dead, or missing targets default to pet follow
- Adds a direct key binding entry under `Key Bindings -> AddOns`
- Keeps the addon focused on a lightweight single-button pet command

## Install

1. Download or clone this repository.
2. Place the `OneButtonPet` folder in:
   - `World of Warcraft/_anniversary_/Interface/AddOns/`
3. Launch the game and enable `OneButtonPet` in the AddOns list.

The addon replaces the usual split macro logic:

```text
#showtooltip
/petattack [harm,nodead]
/petfollow [dead]
/petfollow [help]
/petfollow [noexists]
```

with a single toggle command:

```text
#showtooltip
/pettoggle
```

## Contributing

Development notes and contribution expectations are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release workflow details are in [`RELEASING.md`](RELEASING.md).

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20504`

## Star History

<p align="center">
  <a href="https://star-history.com/#voc0der/OneButtonPet&Date">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=voc0der/OneButtonPet&type=Date&theme=dark" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=voc0der/OneButtonPet&type=Date" />
      <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=voc0der/OneButtonPet&type=Date" />
    </picture>
  </a>
</p>
