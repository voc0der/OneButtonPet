<p align="center">
  <img src="assets/onebuttonpet-icon.png" alt="OneButtonPet icon" width="180" />
</p>

# OneButtonPet

- One button to toggle pet attack and follow on your current target
- Pet control is handled through the addon keybind
- Keeps a short target memory so rapid double-taps still switch cleanly between attack and follow

Current version: `1.0.3`

## In Game

<p align="center">
  <img src="assets/macro-usage-screenshot.png" alt="OneButtonPet macro and keybind usage" width="700" />
</p>

Use `Key Bindings -> AddOns -> OneButtonPet -> Toggle Pet Attack/Follow`.

`/pettoggle`, `/onebuttonpet`, and `/obp` remain available for slash access, and `/pettoggle help` plus `/pettoggle status` still work, but actual pet control is through the addon keybind.

## Usage

- `/pettoggle`
- `/onebuttonpet`
- `/obp`
- `/pettoggle help`
- `/pettoggle status`
- Set `Toggle Pet Attack/Follow` under `Key Bindings -> AddOns -> OneButtonPet`

## Behavior

- First press on a hostile living target sends pet attack
- Second press on that same target toggles pet follow
- Friendly, dead, or missing targets default to pet follow
- Pet control is exposed through a direct key binding entry under `Key Bindings -> AddOns`
- Warns when `/pettoggle` is used in combat, because pet control is handled through the addon keybind
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

with a single addon binding plus an optional slash command:

```text
Key Bindings -> AddOns -> OneButtonPet -> Toggle Pet Attack/Follow
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
