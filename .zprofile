if [ "$(tty)" = "/dev/tty1" ]; then
	exec startx
fi

if [ -d "$HOME/.local/bin" ] ; then
	PATH="$HOME/.local/bin:$PATH"
fi
