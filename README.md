# OneButtonPet

OneButtonPet gives hunters a single addon keybind to switch pet attack and pet follow without juggling split macro logic.

Current version: `1.0.5`

## Setup

1. Install the `OneButtonPet` folder in your TBC Anniversary Classic `Interface/AddOns` directory.
2. Launch the game and enable `OneButtonPet`.
3. Open `Key Bindings -> AddOns`.
4. Find `Toggle Pet Attack/Follow` and bind it.

Pet control is handled through that addon keybind.

## Behavior

- First press on a hostile living target sends pet attack
- Second press on that same target toggles pet follow
- Friendly, dead, or missing targets default to pet follow
- A short remembered-target window keeps rapid double-taps consistent

## Slash Commands

Slash commands still exist, but macros are not the supported pet-control path.

- `/pettoggle`
- `/onebuttonpet`
- `/obp`
- `/pettoggle help`
- `/pettoggle status`

## Scope

- Target client: TBC Anniversary Classic
- TOC interface: `20504`

## Contributing

Development notes are in [`CONTRIBUTING.md`](CONTRIBUTING.md).
Release steps are in [`RELEASING.md`](RELEASING.md).
