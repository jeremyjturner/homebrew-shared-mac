# Demo recordings (maintainers)

These files make the animations in `docs/images/` for the getting-started guide.

You need Tart, a Tart base VM (default name `tahoe-base`), and VHS (`brew install vhs`).

```sh
docs/demo/render.sh
```

The command makes a new VM named `hb-demo`, runs the tapes in order, and stops the VM.
It does not change the host.

Notes:

- The tapes depend on each other. Run them in order.
- Do not run a tape while `hb-demo` is stopped. The tape types into the host shell.
- `Wait+Screen` is unreliable during long Homebrew output. Use a fixed `Sleep`.
- Look at every frame for personal data before you commit a GIF.
