#!/usr/bin/env sh

# ^$ù*"£%µ windows FS

find . -type d -exec chmod 755 {} \;
find . -name '*.bat' -exec chmod 755 {} \;
find . -name '*.sh' -exec chmod 755 {} \;

find . -name '*.rb' -exec chmod 644 {} \;

find . -name '*.java' -exec chmod 644 {} \;
find . -name '*.scala' -exec chmod 644 {} \;
find . -name '*.jar' -exec chmod 644 {} \;

find . -name '*.png' -exec chmod 644 {} \;
find . -name '*.jpg' -exec chmod 644 {} \;
find . -name '*.bmp' -exec chmod 644 {} \;
find . -name '*.gif' -exec chmod 644 {} \;
find . -name '*.mp3' -exec chmod 644 {} \;
find . -name '*.ogg' -exec chmod 644 {} \;
find . -name '*.wav' -exec chmod 644 {} \;
find . -name '*.txt' -exec chmod 644 {} \;

echo chmod ok

# find . | rev | cut -c 1-5 | rev | sed s/[^.]*//|sort|uniq
