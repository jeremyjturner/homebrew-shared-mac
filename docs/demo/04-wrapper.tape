Output docs/images/04-wrapper.gif
Source docs/demo/common.tape

Hide
Type "sudo -v" Enter
Sleep 1s
Type "admin" Enter
Sleep 1s
# The Tart base image has extra taps that print a long warning. Trust them for
# the owner account (trust is stored per user) so the recording stays short.
Type `B=/opt/homebrew/bin/brew; $B as-brew-user update >/dev/null 2>&1; $B as-brew-user trust buildkite/buildkite equinix-labs/otel-cli openai/tools >/dev/null 2>&1; echo UPDATE-FIN""ISHED` Enter
Sleep 3s
Type "admin" Enter
Sleep 15s
Type "admin" Enter
Wait+Screen@300s /UPDATE-FINISHED/
Type "clear" Enter
Show

Type "sudo mkdir -p /usr/local/share/homebrew-shared-mac" Enter
Sleep 1s
Type "sudo cp scripts/brew-wrapper.zsh /usr/local/share/homebrew-shared-mac/" Enter
Sleep 1s
Type "echo 'source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh' >> ~/.zshrc" Enter
Sleep 1s
Type "source ~/.zshrc" Enter
Sleep 1s
Type "brew install hello" Enter
Sleep 3s
Sleep 1s
Type "admin" Enter
Sleep 25s
Sleep 1s
Type "hello" Enter
Sleep 4s
