#!/bin/sh
# -o; guessed with URL and Content-Disposition if empty.
OUTPUT=
# -c; Cookie jar in netscape cookie format.
# "cookie.txt export" extension useful for Chromium
COOKIES=cookies.txt
# -e; Convert remote filename with this encoding to local encoding with iconv(1).
# Tweak this if the filename guessed from content-disposition looks wrongly encoded.
FILENAME_ENCODING=
# -n; No more than this number of threads and
THREAD_MAX=5
# every thread must download more than this bytes. So actual thread number may be lower.
MIN_CHUNK_SIZE=$((8*1024*1024))
RUNDIR=/run/shm
CURLOPTS='# user-agent = "Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 5.1)"
create-dirs
referer = ;auto
fail
globoff
location
# limit-rate = 200k
proto = "=http,https"
remote-time
retry = 5
retry-delay = 5
speed-time = 30
speed-limit = 1024'
usage="${0##*/} [-c cookies(cookies.txt)] [-e filename encoding] [-n threads(5)] [-o output] url"

# The following is dirty code.

die() { echo "$1" >&2; exit 1;}

set -e
while getopts c:e:n:o: opt; do
	case $opt in
	c) COOKIES=$OPTARG;;
	e) FILENAME_ENCODING=$OPTARG;;
	n) THREAD_MAX=$OPTARG;;
	o) OUTPUT=$OPTARG;;
	*) die "$usage";;
	esac
done
shift $((OPTIND-1))
URL="$1"
[ ! "$URL" ] && die "$usage"

dir=`pwd`
tmpdir=`mktemp -d $RUNDIR/multicurl.XXXXXXXXXX`
trap 'exit 1' INT TERM
trap 'rm -r $tmpdir; kill -HUP 0' EXIT
trap : HUP
[ -r "$COOKIES" ] && cp "$COOKIES" $tmpdir/cookies && CURLOPTS="$CURLOPTS\ncookie = cookies\ncookie-jar = cookies"
cd $tmpdir
echo "$CURLOPTS" >config
alias curl='curl "$URL" -Kconfig'

if [ ! "$OUTPUT" ]; then
	# suppressing curl progress bar while maintaining errors
	# haven't figured out a better way to do this
	curl -r0-0 -JO# 2>&1 >stdout | { grep ^curl >&2 ||:;}
	OUTPUT=`grep '^curl: Saved to filename' stdout` || die 'output filename not found'
	[ $FILENAME_ENCODING ] && OUTPUT=`echo "$OUTPUT" | iconv -f$FILENAME_ENCODING`
	OUTPUT=${OUTPUT#*\'}
	OUTPUT=${OUTPUT%\'}
fi
echo Saving to: "\`$OUTPUT'" >&2
prefix="$dir/$OUTPUT.part"

curl -sS -r0-0 -o/dev/null -Dheader
range=`grep '^Content-Range: bytes' header ||:`
length=${range#*/}
length=$((length))
if [ -z "$range" -o $length -lt $((MIN_CHUNK_SIZE*2)) ]; then
	echo Range not supported or file too small. Run in single thread. >&2
	curl -# -o "$dir/$OUTPUT"
	exit 0
fi

chunksize=$((length/THREAD_MAX))
[ $chunksize -lt $MIN_CHUNK_SIZE ] && chunksize=$MIN_CHUNK_SIZE
partnum=$((length/chunksize))
[ $THREAD_MAX -gt $partnum ] && THREAD_MAX=$partnum
echo Download $length bytes in $partnum parts with $THREAD_MAX threads. >&2

for p in `seq 0 $chunksize $((length-chunksize))`; do
	>>"$prefix".$p
done
>"$prefix".$length

while sleep 1; do
	jobs >jobs
	threads=`wc -l <jobs`
	lastbytes=${bytes:-0}
	bytes=`du -bc "$prefix".* | tail -n1`
	bytes=${bytes%%	*}
	[ -t 2 ] && echo -n "\33[0G\33[2K$((bytes*100/length))% $bytes/$length, $threads running, $((($bytes-$lastbytes)/1024))kb/s" >&2
	[ $bytes -ge $length ] && break
	[ $threads -ge $THREAD_MAX ] && continue
	running_parts=" `echo $(pgrep -fl -P $$ curl | grep -o '[0-9]*$' ||:)` "
	for pos in `printf '%s\n' "$prefix".* | grep -o '[0-9]*$' | sort -n`; do
		if [ $start ]; then
			curl -sS -r $start-$((pos-1)) -o "$prefix".$start &
			[ -t 2 ] && echo -n "\33[0G\33[2K" >&2
			echo part: $start-$((pos-1))/$((pos-start)) >&2
			start=
			threads=$((threads+1))
			
			[ $threads -ge $THREAD_MAX ] && break
		fi
		[ "${running_parts##* $pos *}" ] || continue
		size=`stat -c%s "$prefix".$pos`
		pos=$((pos+size))
		[ $size -ne 0 -a -f "$prefix".$pos -o $pos -ge $length ] && continue
		start=$pos
	done
done

[ -t 2 ] && echo >&2
cd "$dir"
echo -n 'Concatenating... '
printf '%s\n' "$prefix".* | sort -V | xargs cat >"$OUTPUT"
rm "$prefix".*
echo "\`$OUTPUT'" saved. >&2
