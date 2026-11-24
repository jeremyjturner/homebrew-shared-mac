# Demo recordings (maintainers)

`record.py` drives a shell in the demo VM, records it with asciinema, and converts each recording to a GIF with agg. The GIFs go in `docs/images/` for the getting-started guide.

You need Tart, asciinema and agg (`brew install asciinema agg`). The base VM is the pristine `ghcr.io/cirruslabs/macos-tahoe-base:latest` by default.

```sh
docs/demo/render.sh
```

The command makes a new VM named `hb-demo`, runs the clips in order, and stops the VM.
It does not change the host.

Notes:

- The clips depend on each other. They run in order.
- `record.py` stops if the VM `hb-demo` is not running.
- The driver waits for text in the output stream, not for pixels. Hidden setup is cut from the start of each clip.
- Look at every frame for personal data before you commit a GIF.
