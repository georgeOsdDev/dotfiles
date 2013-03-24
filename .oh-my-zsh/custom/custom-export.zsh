export PATH=$PATH:$HOME/bin
export PATH=$PATH:/usr/local/sbin

#for homebrew installed
export PATH=/usr/Local/bin:$PATH

#mongodb path
export PATH=$PATH:/usr/local/Cellar/mongodb/2.0.2-x86_64/bin

#JAVA path
export JAVA_HOME=/System/Library/java/JavaVirtualMachines/1.6.0.jdk/Contents/Home
export PATH=$PATH:$JAVA_HOME/bin

#Scala path
export SCALA_HOME=/usr/local/Cellar/scala/2.9.1
export PATH=$PATH:$SCALA_HOME/bin

#for maven
export M2_HOME=/usr/share/maven
export M2_REPO=$HOME/.m2/repository
export PATH=$PATH:M2_HOME/bin

#for play Framework
export PLAY_HOME=$HOME/Library/play-2.0
export PATH=$PATH:$PLAY_HOME

#for lua
export LUA_PATH='/usr/Local/share/lua/5.1/?.lua;/usr/Local/share/lua/5.1/?/init.lua;/Users/oshidatakeharu/.luarocks/share/lua/5.1/?.lua;/Users/oshidatakeharu/.luarocks/share/lua/5.1/?/init.lua;/usr/Local/Cellar/luarocks/2.0.10/share/lua/5.1//?.lua;/usr/Local/Cellar/luarocks/2.0.10/share/lua/5.1//?/init.lua;./?.lua;/usr/Local/share/lua/5.1/?.lua;/usr/Local/share/lua/5.1/?/init.lua;/usr/Local/lib/lua/5.1/?.lua;/usr/Local/lib/lua/5.1/?/init.lua'
export LUA_CPATH='/usr/Local/lib/lua/5.1/?.so;/Users/oshidatakeharu/.luarocks/lib/lua/5.1/?.so;./?.so;/usr/Local/lib/lua/5.1/?.so;/usr/Local/lib/lua/5.1/loadall.so'

export PATH=$HOME/.nodebrew/current/bin:$PATH

# Load RVM into a shell session *as a function*
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
