# DHH Shell

An opinionated Quickshell desktop gremlin for Omarchy.

DHH Shell is intentionally not a general framework. It ships one DHH-inspired sprite, sits on your Hyprland desktop, reacts to Omarchy actions, and drops short Unix-prophet commentary while you work.

## Requirements

- Omarchy, or a Hyprland setup close enough to Omarchy
- Quickshell available as `qs`
- `jq`

Omarchy already provides most of the surrounding pieces this integrates with: Hyprland bindings, Omarchy hooks, Mako notifications, menus, and system helpers.

## Run

```bash
./bin/dhh-shell-dev
```

Stop the running shell:

```bash
qs kill -p "$(pwd)/.cache/shell.qml"
```

`dhh-shell-dev` generates `.cache/shell.qml` from `qml/shell.qml` with the current repo path. That keeps the checked-in QML portable.

## Optional Install

Clone wherever you keep dotfiles or local tools:

```bash
git clone <repo-url> ~/.config/dhh-shell
cd ~/.config/dhh-shell
./bin/dhh-shell-dev
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

- Left-drag DHH to move him around.
- Right-click DHH to show CPU/RAM/battery status.
- Middle-click DHH to reset him to the bottom-right.

## Commentary

Send a message bubble and play an animation:

```bash
./bin/dhh-shell-notify --state wave "DHH online"
```

Open the native command palette:

```bash
./bin/dhh-shell-command open
```

Send an opinionated Omarchy/desktop event:

```bash
./bin/dhh-shell-omarchy-event keybindings
./bin/dhh-shell-omarchy-event screenshot
./bin/dhh-shell-omarchy-event capture-menu
./bin/dhh-shell-omarchy-event recording-start
./bin/dhh-shell-omarchy-event recording-stop
./bin/dhh-shell-omarchy-event system-menu
./bin/dhh-shell-omarchy-event theme-menu
./bin/dhh-shell-omarchy-event background-menu
./bin/dhh-shell-omarchy-event update
./bin/dhh-shell-omarchy-event update-done
./bin/dhh-shell-omarchy-event theme-set mocha_v2
./bin/dhh-shell-omarchy-event font-set "TX-02"
./bin/dhh-shell-omarchy-event battery-low 17
./bin/dhh-shell-omarchy-event post-boot
./bin/dhh-shell-omarchy-event launcher
./bin/dhh-shell-omarchy-event activity
```

Useful Omarchy hooks for automatic commentary:

```text
~/.config/omarchy/hooks/post-update.d/dhh-shell-commentary
~/.config/omarchy/hooks/theme-set.d/dhh-shell-commentary
~/.config/omarchy/hooks/font-set.d/dhh-shell-commentary
~/.config/omarchy/hooks/battery-low.d/dhh-shell-commentary
~/.config/omarchy/hooks/post-boot.d/dhh-shell-commentary
```

Available animation states:

```text
wave alert thinking sad coding review jump
```

Quick demo:

```bash
for state in wave thinking review jump sad alert; do
  ./bin/dhh-shell-notify --state "$state" --duration 1800 "demo: $state"
  sleep 2
done
```

## Sprite Layout

The bundled DHH sheet uses:

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

The runtime asset lives in `assets/dhh/`. Users do not need generation tools or source references.

## Git Hygiene

`references/` is ignored because it contains bulky generation inputs, prompts, decoded frames, and QA intermediates. Runtime assets live under `assets/dhh/` and are tracked.
