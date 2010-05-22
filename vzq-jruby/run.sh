unset XMODIFIERS
jruby -J-Djava.library.path=./`ls -d lib/lwjgl-* | sort -r | head -n 1`/native/`test $(uname -s) = Linux && echo linux || echo macosx`/ "$@" main.rb
