# Petshell

A tiny Quickshell desktop pet overlay for Omarchy/Hyprland.

The current base is a DHH-inspired sprite pet with draggable movement, system-state reactions, and a small event bridge for demo bubbles.

## Requirements

- Omarchy or another Hyprland setup with Quickshell available as `qs`
- `jq`
- ImageMagick, only needed for rebuilding sprite variants

## Run

```bash
./bin/petshell-dev
```

Stop the running shell:

```bash
qs kill -p "$(pwd)/.cache/shell.qml"
```

`petshell-dev` generates `.cache/shell.qml` from `qml/shell.qml` with the current repo path. That keeps the checked-in QML portable.

## Optional Install

Clone wherever you keep dotfiles or local tools:

```bash
git clone <repo-url> ~/.config/petshell
cd ~/.config/petshell
./bin/petshell-dev
```

Enable optional integrations explicitly:

```bash
./install/enable-omarchy-hooks
./install/enable-hypr-bindings
./install/enable-autostart
```

Or enable all optional integrations:

```bash
./install/enable-all
hyprctl reload
```

Disable optional integrations:

```bash
./install/disable-omarchy-hooks
./install/disable-hypr-bindings
./install/disable-autostart
```

Or disable all optional integrations:

```bash
./install/disable-all
hyprctl reload
```

The install scripts only write marked user-config blocks/files under `~/.config`; they do not edit Omarchy source files.

## Controls

- Left-drag the pet to move it around.
- Right-click the pet to show CPU/RAM/battery status.
- Middle-click the pet to reset it to the bottom-right.

## Events

Send a message bubble and play an animation:

```bash
./bin/petshell-notify --state wave "DHH online"
```

Send an opinionated Omarchy/desktop event:

```bash
./bin/petshell-omarchy-event keybindings
./bin/petshell-omarchy-event screenshot
./bin/petshell-omarchy-event capture-menu
./bin/petshell-omarchy-event recording-start
./bin/petshell-omarchy-event recording-stop
./bin/petshell-omarchy-event system-menu
./bin/petshell-omarchy-event theme-menu
./bin/petshell-omarchy-event background-menu
./bin/petshell-omarchy-event update
./bin/petshell-omarchy-event update-done
./bin/petshell-omarchy-event theme-set mocha_v2
./bin/petshell-omarchy-event font-set "TX-02"
./bin/petshell-omarchy-event battery-low 17
./bin/petshell-omarchy-event post-boot
./bin/petshell-omarchy-event launcher
./bin/petshell-omarchy-event activity
```

Useful Omarchy hooks for automatic commentary:

```text
~/.config/omarchy/hooks/post-update.d/petshell-commentary
~/.config/omarchy/hooks/theme-set.d/petshell-commentary
~/.config/omarchy/hooks/font-set.d/petshell-commentary
~/.config/omarchy/hooks/battery-low.d/petshell-commentary
~/.config/omarchy/hooks/post-boot.d/petshell-commentary
```

Available states:

```text
wave alert thinking sad coding review jump
```

Quick demo:

```bash
for state in wave thinking review jump sad alert; do
  ./bin/petshell-notify --state "$state" --duration 1800 "demo: $state"
  sleep 2
done
```

## Pet Variants

List variants:

```bash
./bin/petshell-pet list
```

Switch active pet:

```bash
./bin/petshell-pet set dhh-pet
./bin/petshell-pet set dhh-hybrid
./bin/petshell-pet set dhh-v1-laptop
./bin/petshell-pet set dhh-v2
```

Current variants:

- `dhh-pet`: active alias, currently the same sprite as `dhh-hybrid`.
- `dhh-hybrid`: v1 laptop sprite set, with only row 6 `waiting` and row 8 `review` replaced from v2.
- `dhh-v1-laptop`: original DHH laptop sprite set.
- `dhh-v2`: no-laptop sprite set.

## Sprite Layout

All DHH sheets use:

- `1536x1872` spritesheet
- `8` columns by `9` rows
- `192x208` frame cells

Rows:

```text
0 idle
1 running-right
2 running-left
3 waving
4 jumping
5 failed/sad
6 waiting/thinking
7 running/coding alternate
8 review/coding
```

The hybrid sheet is built by appending full rows instead of alpha-compositing. This matters because compositing transparent rows can leave hidden pixels from the previous row and cause visual overlap.

Rebuild the hybrid:

```bash
./scripts/build-dhh-hybrid
```

## Git Hygiene

`references/` is ignored because it contains bulky generation inputs, prompts, decoded frames, and QA intermediates. Runtime pet assets live under `pets/` and are tracked.
