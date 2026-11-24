# Shared settings. Run vhs from the repository root.
Set Shell "bash"
Set FontSize 18
Set Width 1100
Set Height 620
Set Padding 20
Set TypingSpeed 45ms
Set WaitTimeout 90s

# Hidden: open a shell inside the demo VM with a short prompt.
Hide
Type "export PS1='$ '; clear" Enter
Type "tart exec -i -t hb-demo zsh -l" Enter
Sleep 4s
Type "PROMPT='$ '; cd ~/homebrew-shared-mac; clear" Enter
Sleep 1s
Show
