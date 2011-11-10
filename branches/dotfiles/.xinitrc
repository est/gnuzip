PROG=Xsession
ERR=~/.xsession-errors
USRRES=~/.Xresources

exec >>$ERR 2>&1
echo "$PROG: X session started for $LOGNAME at $(date)"

numlockx on
[ -f "$USRRES" ] && xrdb -merge $USRRES

killall --quiet urxvtd
urxvtd --quiet --opendisplay --fork

export XMODIFIERS="@im=xsunpinyin"
export GTK_IM_MODULE=xim
killall --quiet xsunpinyin
xsunpinyin -d >/dev/null

export _JAVA_AWT_WM_NONREPARENTING=1

exec x-window-manager
