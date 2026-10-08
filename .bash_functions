# ===================================================
# VMD - Tube - MOVIE - Render a movie of the trajectory with the same representation as vmdt
# Usage: vmdm [STRUCT] [TRAJ ...] [key=value ...]     e.g.  vmdm system.pdb traj{1..5}.xtc stride=10 box=1
# - a vmd.config file is required in the usage directory
# (it can also be run directly as a script: ./vmdm.sh [STRUCT] [TRAJ ...] [key=value ...])
# ===================================================

_vmdm_reps_tcl() {
	if [ -n "${reps:-}" ]; then
		printf '%s\n' "$reps"
		return
	fi
	cat <<'EOF'
axes location Off
display projection Orthographic
color Display Background white
display backgroundgradient off
mol modstyle 0 0 NewCartoon
mol modcolor 0 0 Chain
mol modselect 0 0 protein or nucleic
mol material Opaque
EOF
}

_vmdm_box_tcl() {
	cat <<'EOF'
# Periodic box drawn by hand as 12 static edges around a FIXED centre, so it
# does not follow the centre of mass of the (aligned) atoms from frame to frame.
set vmdm_boxcolor black
set vmdm_boxwidth 2

# Cell vectors {A B C} of the current frame, or {} if the frame has no cell.
proc vmdm_cellvecs {} {
	lassign [molinfo top get {a b c alpha beta gamma}] a b c al be ga
	if {$a <= 0 || $b <= 0 || $c <= 0} {
		return {}
	}
	set d2r [expr {acos(-1.0) / 180.0}]
	set ca [expr {cos($al * $d2r)}]
	set cb [expr {cos($be * $d2r)}]
	set cg [expr {cos($ga * $d2r)}]
	set sg [expr {sin($ga * $d2r)}]
	set A [list $a 0.0 0.0]
	set B [list [expr {$b * $cg}] [expr {$b * $sg}] 0.0]
	set cx [expr {$c * $cb}]
	set cy [expr {$c * ($ca - $cb * $cg) / $sg}]
	set cz [expr {sqrt(max(0.0, $c * $c - $cx * $cx - $cy * $cy))}]
	return [list $A $B [list $cx $cy $cz]]
}

# Redraw the box of the current frame centred on $center (replaces the previous one).
proc vmdm_drawbox {center} {
	graphics top delete all
	set vs [vmdm_cellvecs]
	if {[llength $vs] == 0} {
		return
	}
	set o [vecsub $center [vecscale 0.5 [vecadd {*}$vs]]]
	graphics top color $::vmdm_boxcolor
	foreach {e u w} {0 1 2 1 2 0 2 0 1} {
		foreach i {0 1} {
			foreach j {0 1} {
				set p [vecadd $o [vecscale $i [lindex $vs $u]] [vecscale $j [lindex $vs $w]]]
				graphics top line $p [vecadd $p [lindex $vs $e]] width $::vmdm_boxwidth style solid
			}
		}
	}
}

# Scale the view (after a 'display resetview') so the box centred on $center fits
# on screen. resetview only frames the atoms, so compare the atoms' extent with
# the box's extent around the view centre and zoom out by the ratio if needed.
proc vmdm_fitbox {center} {
	set vs [vmdm_cellvecs]
	if {[llength $vs] == 0} {
		puts "RENDER) no unit cell on this frame; box zoom fit skipped"
		return
	}
	lassign $vs A B C
	set all [atomselect top all]
	set mm [measure minmax $all]
	$all delete
	set ratom 0.0
	foreach lo [lindex $mm 0] hi [lindex $mm 1] {
		set ratom [expr {max($ratom, $hi - $lo)}]
	}

	set vc [lindex [molinfo top get center] 0]
	set origin [vecsub $center [vecscale 0.5 [vecadd $A $B $C]]]
	set dev {0.0 0.0 0.0}
	foreach i {0 1} {
		foreach j {0 1} {
			foreach k {0 1} {
				set corner [vecadd $origin [vecscale $i $A] [vecscale $j $B] [vecscale $k $C]]
				set d [vecsub $corner $vc]
				set newdev {}
				foreach m $dev x $d {
					lappend newdev [expr {max($m, abs($x))}]
				}
				set dev $newdev
			}
		}
	}
	set rbox 0.0
	foreach m $dev {
		set rbox [expr {max($rbox, 1.0 * $m)}]
	}
	set f [expr {min(1.0, $ratom / $rbox)}]
	scale by $f
	puts [format "RENDER) box fit: atom extent %.1f A, box extent %.1f A, extra zoom %.3f" $ratom $rbox $f]
}
EOF
}

_vmdm_usage() {
	cat >&2 <<'EOF'
Usage: vmdm STRUCT [TRAJ ...] [key=value ...]
  Reads ./vmd.config (required). TRAJ files (.dcd/.xtc/.trr) are loaded one after
  another, e.g. traj{1..5}.xtc or part*.xtc; with no TRAJ, STRUCT opens in the VMD GUI.
  key=value arguments override vmd.config for this run, e.g. stride=10 box=1
EOF
}

# Set one config key. Writes into the caller's (vmdm's) local variable of the same
# meaning via bash dynamic scoping. Args: KEY VALUE WHERE
_vmdm_set() {
	local _var _v="$2"
	case "$1" in
		traj_type)	_var=ttype ;;
		sort)		_var=tsort ;;
		step)		_var=step ;;
		stride)		_var=stride ;;
		md_ts_fs)	_var=md_ts_fs ;;
		md_nsave)	_var=md_nsave ;;
		align_sel)	_var=alignsel ;;
		pbc_sel)	_var=pbcsel ;;
		reps)		_var=reps ;;
		vmd)		_var=vmdbin ;;
		frames_dir)	_var=framesdir ;;
		imgsize)	_var=imgsize ;;
		zoom)		_var=zoom ;;
		box)		_var=box ;;
		fps)		_var=fps ;;
		mp4)		_var=movie ;;
		stamp)		_var=stamp ;;
		t0)		_var=t0 ;;
		tdec)		_var=tdec ;;
		tsize)		_var=tsize ;;
		tx)		_var=tx ;;
		ty)		_var=ty ;;
		tcolor)		_var=tcolor ;;
		tfont)		_var=tfont ;;
		*)
			echo "Error: $3: unknown key '$1' (keys are lower case; see vmd.config)" >&2
			return 1
			;;
	esac
	[[ "$_v" == "~/"* ]] && _v="$HOME/${_v#\~/}"
	printf -v "$_var" '%s' "$_v"
}

# Read a config file of 'key = value' lines. Blank lines and lines starting with
# '#' are ignored; ' # ...' after a value is a comment. Values may be wrapped in
# "double" or 'single' quotes to keep a literal '#'. An empty value means "auto".
# A multi-line value is written as 'key = <<END', then the lines, then a line
# 'END'; those lines are taken verbatim (no comment stripping).
_vmdm_readcfg() {
	local _f="$1" _line _k _v _n=0 _end _start _blk _done _re_end
	local _re_blk='^<<[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*(#.*)?$'
	local _re_skip='^[[:space:]]*(#|$)'
	local _re_kv='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*)$'
	local _re_dq='^"([^"]*)"[[:space:]]*(#.*)?$'
	local _re_sq="^'([^']*)'[[:space:]]*(#.*)?\$"
	while IFS= read -r _line || [ -n "$_line" ]; do
		_n=$((_n + 1))
		_line="${_line%$'\r'}"
		[[ "$_line" =~ $_re_skip ]] && continue
		if ! [[ "$_line" =~ $_re_kv ]]; then
			echo "Error: $_f:$_n: expected 'key = value', got: $_line" >&2
			return 1
		fi
		_k="${BASH_REMATCH[1]}"
		_v="${BASH_REMATCH[2]}"
		if [[ "$_v" =~ $_re_blk ]]; then
			_end="${BASH_REMATCH[1]}"
			_re_end="^[[:space:]]*${_end}[[:space:]]*\$"
			_start=$_n _blk="" _done=0
			while IFS= read -r _line || [ -n "$_line" ]; do
				_n=$((_n + 1))
				_line="${_line%$'\r'}"
				if [[ "$_line" =~ $_re_end ]]; then
					_done=1
					break
				fi
				_blk+="$_line"$'\n'
			done
			if [ "$_done" != 1 ]; then
				echo "Error: $_f:$_start: block '$_k = <<$_end' is not closed by a line '$_end'" >&2
				return 1
			fi
			_v="${_blk%$'\n'}"
		elif [[ "$_v" =~ $_re_dq ]] || [[ "$_v" =~ $_re_sq ]]; then
			_v="${BASH_REMATCH[1]}"
		else
			[[ "$_v" == "#"* ]] && _v=""
			_v="${_v%%[[:space:]]#*}"
			_v="${_v%"${_v##*[![:space:]]}"}"
		fi
		_vmdm_set "$_k" "$_v" "$_f:$_n" || return 1
	done < "$_f"
}

vmdm() {
	local cfg="vmd.config"	# always read from the current directory
	if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
		_vmdm_usage
		[ $# -gt 0 ]
		return
	fi
	if [ ! -r "$cfg" ]; then
		echo "Error: no readable $cfg in $PWD (vmdm needs one in the directory it is run from)" >&2
		return 1
	fi

	# --- Built-in defaults; vmd.config and key=value arguments override these ---
	local struct="" ttype="" tsort=1 step=1 stride=1
	local md_ts_fs=10 md_nsave=1000
	local alignsel="" pbcsel="not water" reps=""
	local vmdbin="vmd" framesdir="frames" imgsize="1000x1000" zoom=0.92 box=0
	local fps=8 movie=""
	local stamp=1 t0="" tdec="" tsize=40 tx=0.03 ty=0.03 tcolor="black" tfont="Sans"
	local tunit="ns"
	local -a trajs=() overrides=() ttypes=()

	# Split arguments: key=value (and not an existing file) -> override; else
	# the first is the structure and the rest are trajectory files, in order.
	local arg
	local re_ov='^[A-Za-z_][A-Za-z0-9_]*='
	for arg in "$@"; do
		if [[ "$arg" =~ $re_ov ]] && [ ! -e "$arg" ]; then
			overrides+=("$arg")
		elif [ -z "$struct" ]; then
			struct="$arg"
		else
			trajs+=("$arg")
		fi
	done

	_vmdm_readcfg "$cfg" || return 1
	for arg in ${overrides[@]+"${overrides[@]}"}; do
		_vmdm_set "${arg%%=*}" "${arg#*=}" "command line" || return 1
	done
	echo "Config: $PWD/$cfg"
	[ -n "$reps" ] || echo "Note: no 'reps' block in $cfg; using a default cartoon representation" >&2

	local numre='^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$'
	if [ -z "$struct" ]; then
		echo "Error: no structure file given" >&2
		_vmdm_usage
		return 1
	fi
	if [ ! -r "$struct" ]; then
		echo "Error: cannot read structure file '$struct'" >&2
		return 1
	fi
	if ! [[ "$tsort" =~ ^[01]$ ]]; then
		echo "Error: sort must be 0 (keep given order) or 1 (natural sort) (got '$tsort')" >&2
		return 1
	fi
	# Shell globs sort traj10 before traj2, so put the files in natural (version) order.
	if [ "$tsort" = 1 ] && [ ${#trajs[@]} -gt 1 ]; then
		local sorted line
		if sorted="$(printf '%s\n' "${trajs[@]}" | sort -V 2>/dev/null)" && [ -n "$sorted" ]; then
			trajs=()
			while IFS= read -r line; do
				trajs+=("$line")
			done <<< "$sorted"
		else
			echo "Warning: 'sort -V' is not available; loading trajectories in the order given" >&2
		fi
	fi
	local f ext
	for f in ${trajs[@]+"${trajs[@]}"}; do
		if [ ! -r "$f" ]; then
			echo "Error: cannot read trajectory file '$f'" >&2
			return 1
		fi
		if [ -n "$ttype" ]; then
			ttypes+=("$ttype")
		else
			ext="$(printf '%s' "${f##*.}" | tr '[:upper:]' '[:lower:]')"
			case "$ext" in
				dcd|xtc|trr) ttypes+=("$ext") ;;
				*)
					echo "Error: unrecognised trajectory extension '.$ext' in '$f' (expected .dcd, .xtc or .trr; or set traj_type)" >&2
					return 1
					;;
			esac
		fi
	done
	if ! [[ "$stride" =~ ^[1-9][0-9]*$ ]]; then
		echo "Error: stride must be a positive integer (got '$stride')" >&2
		return 1
	fi
	if ! [[ "$step" =~ ^[1-9][0-9]*$ ]]; then
		echo "Error: step must be a positive integer (got '$step')" >&2
		return 1
	fi
	if ! [[ "$md_ts_fs" =~ $numre ]] || ! awk -v x="$md_ts_fs" 'BEGIN{exit !(x > 0)}'; then
		echo "Error: md_ts_fs must be a positive number (got '$md_ts_fs')" >&2
		return 1
	fi
	if ! [[ "$md_nsave" =~ ^[1-9][0-9]*$ ]]; then
		echo "Error: md_nsave must be a positive integer (got '$md_nsave')" >&2
		return 1
	fi
	local dt
	dt="$(awk -v ts="$md_ts_fs" -v ns="$md_nsave" 'BEGIN{printf "%.12g", ts*ns*1e-6}')"	# ns per saved frame
	[[ "$imgsize" =~ ^[0-9]+$ ]] && imgsize="${imgsize}x${imgsize}"
	if ! [[ "$imgsize" =~ ^[0-9]+x[0-9]+$ ]]; then
		echo "Error: imgsize must be WxH or a single number (got '$imgsize')" >&2
		return 1
	fi
	if ! [[ "$zoom" =~ ^[0-9]*\.?[0-9]+$ ]]; then
		echo "Error: zoom must be a positive number (got '$zoom')" >&2
		return 1
	fi
	if ! [[ "$stamp" =~ ^[01]$ ]]; then
		echo "Error: stamp must be 0 (off) or 1 (on) (got '$stamp')" >&2
		return 1
	fi
	if [ "$stamp" = 1 ] && [ ${#trajs[@]} -gt 0 ]; then
		# Default decimals: just enough that every movie frame shows a new value.
		if [ -z "$tdec" ]; then
			tdec="$(awk -v s="$stride" -v st="$step" -v dt="$dt" 'BEGIN{x=s*st*dt; d=0; while (d < 6 && x*10^d < 0.999999) d++; print d}')"
		fi
		# Time of the first trajectory frame: GROMACS xtc/trr write t=0 first,
		# DCD writers (NAMD/CHARMM/OpenMM) write their first frame after one save interval.
		if [ -z "$t0" ]; then
			if [ "${ttypes[0]}" = dcd ]; then t0="$dt"; else t0=0; fi
		fi
		if ! [[ "$t0" =~ $numre ]]; then
			echo "Error: t0 must be a number (got '$t0')" >&2
			return 1
		fi
		if ! [[ "$tdec" =~ ^[0-6]$ ]]; then
			echo "Error: tdec must be an integer 0-6 (got '$tdec')" >&2
			return 1
		fi
		if ! [[ "$tsize" =~ ^[1-9][0-9]*$ ]]; then
			echo "Error: tsize must be a positive integer (got '$tsize')" >&2
			return 1
		fi
		local q
		for q in tx ty; do
			if ! [[ "${!q}" =~ $numre ]] || ! awk -v x="${!q}" 'BEGIN{exit !(x >= 0 && x <= 1)}'; then
				echo "Error: $q must be a number from 0 to 1 (got '${!q}')" >&2
				return 1
			fi
		done
	fi
	if ! [[ "$box" =~ ^[01]$ ]]; then
		echo "Error: box must be 0 (off) or 1 (on) (got '$box')" >&2
		return 1
	fi
	if ! [[ "$fps" =~ ^[0-9]+$ ]] || [ "$fps" -lt 1 ]; then
		echo "Error: fps must be a positive integer (got '$fps')" >&2
		return 1
	fi

	local tcl
	tcl="$(mktemp -t vmdreps.XXXXXX.tcl)"
	trap 'rm -f "$tcl"; trap - RETURN' RETURN

	if [ ${#trajs[@]} -eq 0 ]; then
		_vmdm_reps_tcl > "$tcl"
		echo 'display rendermode GLSL' >> "$tcl"
		if [ "$box" = 1 ]; then
			_vmdm_box_tcl >> "$tcl"
			cat >> "$tcl" <<'EOF'
set sel [atomselect top all]
set boxcenter [measure center $sel weight mass]
$sel delete
vmdm_drawbox $boxcenter
display resetview
vmdm_fitbox $boxcenter
EOF
		fi
		"$vmdbin" "$struct" -e "$tcl"
		return
	fi

	mkdir -p "$framesdir"
	# Remove frames of an earlier run, which would otherwise end up in this movie.
	rm -f "$framesdir"/frame_*.png "$framesdir"/frame_*.tga
	# Only the frames that will be rendered are loaded: every (step x stride)-th frame
	# of each file. Frames skipped by stride used to be loaded, PBC-unwrapped and
	# aligned anyway, which made the run time and memory scale with the full trajectory.
	local k nskip=$((step * stride))
	{
		printf 'set vmdm_tlast [clock milliseconds]\n'
		printf 'proc vmdm_lap {} {\n\tset now [clock milliseconds]\n\tset dt [expr {($now - $::vmdm_tlast) / 1000.0}]\n\tset ::vmdm_tlast $now\n\treturn [format "%%.1f s" $dt]\n}\n'
		for ((k = 0; k < ${#trajs[@]}; k++)); do
			printf 'set _nf [molinfo top get numframes]\n'
			printf 'mol addfile {%s} type %s first 0 last -1 step %s waitfor all molid top\n' "${trajs[k]}" "${ttypes[k]}" "$nskip"
			printf 'puts "RENDER) loaded [expr {[molinfo top get numframes] - $_nf}] frames from [file tail {%s}] ([vmdm_lap])"\n' "${trajs[k]}"
		done
		_vmdm_reps_tcl
		_vmdm_box_tcl
		echo "display resize ${imgsize%x*} ${imgsize#*x}"
		cat <<EOF
set outdir {$framesdir}
set zoom $zoom
set showbox $box
set pbcsel {$pbcsel}
set alignsel {$alignsel}
if {\$alignsel eq ""} {
	set alignsel none
}
set n [molinfo top get numframes]
puts "RENDER) \$n frames (structure + every $nskip-th trajectory frame) -> \$n images into \$outdir"

if {\$n > 1} {
	set cellprops {a b c alpha beta gamma}
	animate goto 1
	set cell [molinfo top get \$cellprops]
	animate goto 0
	if {[lindex [molinfo top get \$cellprops] 0] == 0} {
		molinfo top set \$cellprops \$cell
		puts "RENDER) copied unit cell \$cell onto the structure frame"
	}
}

# Make molecules whole on frame 0 only, then unwrap the later frames against it:
# unwrapping keeps them whole, so joining every frame (the slowest pbctools step)
# is not needed. Restricting both to pbc_sel skips the solvent, which is most atoms.
if {\$pbcsel eq ""} {
	puts "RENDER) pbc join/unwrap off (pbc_sel empty)"
} elseif {[catch {
	package require pbctools
	pbc join fragment -first 0 -last 0 -sel \$pbcsel
	pbc unwrap -all -sel \$pbcsel
} err]} {
	puts "RENDER) pbc join/unwrap skipped: \$err"
} else {
	puts "RENDER) pbc join (frame 0) + unwrap of '\$pbcsel' ([vmdm_lap])"
}

set all [atomselect top all]
set fit [atomselect top \$alignsel]
if {[\$fit num] == 0} {
	puts "RENDER) WARNING: no alignment atoms (align_sel '\$alignsel'); centring each frame on its centre of mass instead"
	for {set i 0} {\$i < \$n} {incr i} {
		\$all frame \$i
		\$all moveby [vecinvert [measure center \$all weight mass]]
	}
} else {
	set ref [atomselect top \$alignsel frame 0]
	\$all frame 0
	\$all moveby [vecinvert [measure center \$ref weight mass]]
	set maxrmsd 0.0
	for {set i 1} {\$i < \$n} {incr i} {
		\$all frame \$i
		\$fit frame \$i
		\$all move [measure fit \$fit \$ref]
		set maxrmsd [expr {max(\$maxrmsd, [measure rmsd \$fit \$ref])}]
	}
	puts [format "RENDER) aligned %d atoms of '%s' to frame 0, max post-fit RMSD %.2f A (%s)" [\$fit num] \$alignsel \$maxrmsd [vmdm_lap]]
	\$ref delete
}
\$fit delete

\$all delete
if {\$showbox} {
	set sel [atomselect top all frame 0]
	set boxcenter [measure center \$sel weight mass]
	\$sel delete
	animate goto 0
	vmdm_drawbox \$boxcenter
	puts "RENDER) drawing periodic box fixed at frame-0 centre {\$boxcenter}"
}
animate goto 0
display update
display resetview
if {\$showbox} {
	vmdm_fitbox \$boxcenter
}
scale by \$zoom
puts "RENDER) view reset on frame 0, zoom \$zoom"

for {set i 0} {\$i < \$n} {incr i} {
	animate goto \$i
	if {\$showbox} {
		vmdm_drawbox \$boxcenter
	}
	display update
	render TachyonInternal [format "%s/frame_%05d.tga" \$outdir \$i]
}
puts "RENDER) rendered \$n images ([vmdm_lap])"
quit
EOF
	} > "$tcl"

	echo "Rendering ${#trajs[@]} trajectory file(s) in this order (every ${nskip}-th frame: step $step x stride $stride) -> $framesdir/ ..."
	printf '  %s\n' "${trajs[@]}"
	if [ ${#trajs[@]} -gt 1 ] && [ "$nskip" -gt 1 ]; then
		echo "Note: VMD restarts the frame count in every file; time stamps stay exact only if each file but the last has a multiple of $nskip frames." >&2
	fi
	"$vmdbin" "$struct" -dispdev text -e "$tcl" 2>&1 | grep -E 'RENDER\)|ERROR' || true

	local n_tga ncpu tconv=$SECONDS
	n_tga=$(find "$framesdir" -maxdepth 1 -name 'frame_*.tga' | wc -l)
	ncpu="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
	if [ "$n_tga" -gt 0 ]; then
		echo "Converting $n_tga TGA -> PNG on $ncpu cores ..."
		if command -v magick >/dev/null 2>&1; then
			find "$framesdir" -maxdepth 1 -name 'frame_*.tga' -print0 \
				| xargs -0 -n 20 -P "$ncpu" magick mogrify -format png \
				&& rm -f "$framesdir"/frame_*.tga
		elif command -v convert >/dev/null 2>&1; then
			find "$framesdir" -maxdepth 1 -name 'frame_*.tga' -print0 \
				| xargs -0 -n 1 -P "$ncpu" sh -c 'convert "$1" "${1%.tga}.png" && rm -f "$1"' _
		elif python3 -c 'import PIL' 2>/dev/null; then
			python3 - "$framesdir" "$ncpu" <<'PYEOF'
import glob, os, sys
from multiprocessing import Pool
from PIL import Image
def conv(f):
    Image.open(f).save(f[:-4] + ".png")
    os.remove(f)
if __name__ == "__main__":
    with Pool(int(sys.argv[2])) as p:
        p.map(conv, sorted(glob.glob(os.path.join(sys.argv[1], "frame_*.tga"))))
PYEOF
		else
			echo "Error: need ImageMagick ('magick'/'convert') or Python Pillow to write PNG." >&2
			echo "       Unconverted Targa frames left in $framesdir/" >&2
			return 1
		fi
		echo "Converted in $((SECONDS - tconv)) s"
	fi
	echo "Wrote $(find "$framesdir" -maxdepth 1 -name 'frame_*.png' | wc -l) PNG frames to $framesdir/"

	if ! command -v ffmpeg >/dev/null 2>&1; then
		echo "ffmpeg not found; frames left in $framesdir/, no movie written." >&2
		return 0
	fi
	if [ -z "$movie" ]; then
		# traj.xtc -> traj.mp4; traj1.xtc ... traj5.xtc -> traj1-traj5.mp4
		movie="${trajs[0]%.*}"
		if [ ${#trajs[@]} -gt 1 ]; then
			local last="${trajs[${#trajs[@]}-1]##*/}"
			movie+="-${last%.*}"
		fi
		movie+=".mp4"
	fi
	local vf="scale=trunc(iw/2)*2:trunc(ih/2)*2"
	if [ "$stamp" = 1 ]; then
		# Movie frame n is VMD frame n; VMD frame 0 is the structure and frame n>=1 is
		# trajectory frame (n-1)*step*stride, i.e. t = T0 + (n-1)*step*stride*dt.
		# So t(n) = a*n + b with a = stride*step*dt and b = T0 - a. The structure
		# frame (n=0) is labelled with the run's start time S: T0 for xtc/trr, T0 - dt for dcd.
		local a b p st0 fontopt texpr
		read -r a b p st0 < <(awk -v s="$stride" -v st="$step" -v dt="$dt" -v t0="$t0" -v d="$tdec" -v isdcd="$([ "${ttypes[0]}" = dcd ] && echo 1 || echo 0)" \
			'BEGIN{printf "%.12g %.12g %d %.12g\n", s*st*dt, t0-s*st*dt, 10^d, t0-isdcd*dt}')
		local h="round(max(${st0},${a}*n+(${b}))*${p})"
		if [ "$tdec" -eq 0 ]; then
			texpr="%{eif\\:${h}\\:d}"
		else
			texpr="%{eif\\:trunc(${h}/${p})\\:d}.%{eif\\:mod(${h},${p})\\:d\\:${tdec}}"
		fi
		if [ -f "$tfont" ]; then fontopt="fontfile='$tfont'"; else fontopt="font='$tfont'"; fi
		# drawtext's default y_align=text pins the top of the *inked* glyphs, so the
		# baseline shifts by a pixel or more whenever the tallest digit changes
		# (round 0/3/6/8/9 overshoot flat-topped 1/4/5/7). y_align=font pins it to the
		# font's ascent, which is the same in every frame (needs ffmpeg >= 6.1).
		if ffmpeg -hide_banner -h filter=drawtext 2>/dev/null | grep -q 'y_align'; then
			fontopt+=":y_align=font"
		else
			echo "Warning: this ffmpeg's drawtext has no y_align option (needs >= 6.1); the time stamp may shift vertically by a pixel between frames." >&2
		fi
		vf+=",drawtext=${fontopt}:fontsize=${tsize}:fontcolor=${tcolor}:x=${tx}*w:y=${ty}*h:text='t = ${texpr} ${tunit}'"
		echo "Time stamp: ${md_ts_fs} fs x ${md_nsave} steps = ${dt} ns per saved frame; t = ${t0} + (frame-1) x ${step} x ${stride} x ${dt} ns (${a} ns per movie frame, ${tdec} decimals)"
	fi
	echo "Encoding $movie at ${fps} fps ..."
	local tenc=$SECONDS
	ffmpeg -y -loglevel error -framerate "$fps" \
		-pattern_type glob -i "$framesdir/frame_*.png" \
		-vf "$vf" \
		-c:v libx264 -crf 18 -pix_fmt yuv420p -r 30 "$movie"
	echo "Wrote $movie ($((SECONDS - tenc)) s)"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	vmdm "$@"
fi