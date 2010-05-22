for /f "usebackq" %%i in (`dir /b /on lib\lwjgl-*`) do set d=%%i
jruby -J-Djava.library.path=./lib/%d%/native/windows/ main.rb
