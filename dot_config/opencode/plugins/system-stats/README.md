# System stats TUI plugin

Shows system-wide CPU and memory usage in the OpenCode terminal UI.

```
CPU 21%  RAM 6.0G/15.5G
```

- Appears in the home footer and the session prompt footer.
- Values turn yellow at 85% and red at 95%.
- Polls every 2 seconds.
- Uses `/proc/meminfo` `MemAvailable` on Linux; falls back to `os.totalmem()/os.freemem()` elsewhere.

## Install

This directory is auto-discovered because it lives in the global config plugin folder:

```
~/.config/opencode/plugins/system-stats/
├── index.ts      # no-op server entrypoint
├── tui.tsx       # terminal UI entrypoint
├── stats.ts      # sampling and formatting helpers
└── package.json
```

Restart the TUI (or run `/reload`) after changing the plugin.

## Options

The interval is configurable when the plugin is loaded explicitly from `cli.json`:

```json
{
  "plugins": [
    {
      "package": "/home/selu/.config/opencode/plugins/system-stats",
      "options": { "interval": 1000 }
    }
  ]
}
```

`interval` is in milliseconds and is clamped to 500–60000.

## Notes

The plugin samples the machine where the TUI runs. If the TUI is connected to a remote
OpenCode server, the numbers describe the local client, not the remote host.
