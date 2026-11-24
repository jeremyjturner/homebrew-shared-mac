Output docs/images/06-wrong-password.gif
Source docs/demo/common.tape

Type "su - bob" Enter
Sleep 1s
Type "bobpw" Enter
Sleep 2s
Type "PROMPT='$ '; source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh; clear" Enter
Sleep 1s
Type "brew install cowsay" Enter
Sleep 3s
Type "wrong" Enter
Sleep 3s
Type "wrong" Enter
Sleep 3s
Type "wrong" Enter
Sleep 3s
Type "brew list | grep cowsay || echo 'cowsay is not installed'" Enter
Sleep 4s
