#!/bin/sh
GETOPTS=
GETOPTS="${GETOPTS}r:"	# toolchain - tool readelf path
GETOPTS="${GETOPTS}s:"	# toolchain - tool strip path
GETOPTS="${GETOPTS}l:"	# path for find library
GETOPTS="${GETOPTS}o:"	# path for output
GETOPTS="${GETOPTS}v"	# verbose mode

function usage() 
{
	echo "Usage> $0 -v -r path_bin_readelf -s path_bin_strip -o output_dir -l path_for_library_finding  [ BIN_FILE | BIN_DIR | LIB_FILE | LIB_DIR ] ...  "
}
function report()
{
	if [ ! -z $VERBOSE_MODE ] ; then
		echo $@
	fi
}

PATH_BIN_READELF=
PATH_BIN_STRIP=
PATH_OUTPUT=
TARGET_LIBRARY_CHECK=
TARGET_FILE_OR_DIR=
VERBOSE_MODE=

OPTIND=1
while getopts ${GETOPTS} OPTION
do
	case $OPTION in
		v)
			VERBOSE_MODE=1
			;;
		r)
			PATH_BIN_READELF=$OPTARG
			;;
		s)
			PATH_BIN_STRIP=$OPTARG
			;;
		l)
			TARGET_LIBRARY_CHECK="$TARGET_LIBRARY_CHECK $OPTARG"
			;;
		o)
			PATH_OUTPUT=$OPTARG
			;;
		?)
			usage
			exit 1;
	esac
done
shift $(($OPTIND - 1))
while true;
do
	if [ -z $1 ] ; then
		break
	elif [ -z "$TARGET_FILE_OR_DIR" ] ; then
		TARGET_FILE_OR_DIR=$1
		shift
	else
		TARGET_FILE_OR_DIR="$TARGET_FILE_OR_DIR $1"
		shift
	fi
done
# check env
if [ -z $PATH_BIN_READELF ] ; then
	usage
	exit 1
fi
if [ -z "$TARGET_FILE_OR_DIR" ] ; then
	usage
	exit 1
fi
echo "[INFO] READELF: $PATH_BIN_READELF"
if [ -z $PATH_BIN_STRIP ] ; then
	echo "[INFO] STRIP: no use"
else
	echo "[INFO] STRIP: $PATH_BIN_STRIP"
fi
echo "[INFO] OTHER LIB: $TARGET_LIBRARY_CHECK"
echo "[INFO] TARGET: $TARGET_FILE_OR_DIR"
if [ -z $PATH_OUTPUT ] ; then
	echo "[INFO] OUTPUT: no use"
else
	mkdir -p $PATH_OUTPUT/lib $PATH_OUTPUT/bin $PATH_OUTPUT/slib 
	echo "[INFO] OUTPUT: $PATH_OUTPUT/lib $PATH_OUTPUT/bin $PATH_OUTPUT/slib"
fi

echo "-------------"

IFS=' ' read -ra FILE_OR_DIR <<< "$TARGET_FILE_OR_DIR"

declare -A so_objs
declare -A lib_dirs
total_size=0

for target in "${FILE_OR_DIR[@]}"; do
	if [ -d "$target" ] ; then
		echo "BIN DIR: $target"
		if [ -d "$target/../lib" ] ; then
			if [ -z ${lib_dirs["$target/../lib"]} ] ; then
				lib_dirs["$target/../lib"]=$target/../lib
				if [ -z "$TARGET_LIBRARY_CHECK" ] ; then
					TARGET_LIBRARY_CHECK=$target/../lib
				else
					TARGET_LIBRARY_CHECK="$target/../lib $TARGET_LIBRARY_CHECK"
				fi
			fi
		fi
		for bin in `find $target -type f`
		do
			target_output_dir=bin
			if [ `file -L $bin | grep -i -c "shared object" ` == 1 ] ; then
				target_output_dir=lib
			fi
			if [ `file -L $bin | grep -c ELF` != 1 ] ; then
				report "<Skip> $bin"
				if [ ! -z "$PATH_OUTPUT" ] ; then
					cp $bin $PATH_OUTPUT/$target_output_dir
				fi
				continue
			fi
			echo "[Add] $bin: "
			bin_name=`basename $bin`
			if [ "$target_output_dir" == "lib" ] ; then
				so_objs[$bin_name]=$bin_name
			fi
			if [ ! -z "$PATH_OUTPUT" ] ; then
				cp $bin $PATH_OUTPUT/$target_output_dir
				if [ ! -z $PATH_BIN_STRIP ] ; then
					$PATH_BIN_STRIP $PATH_OUTPUT/$target_output_dir/$bin_name
				fi
			fi
			for so in `$PATH_BIN_READELF -a $bin | grep Shared | awk -F'[' '{split($2,array,"]"); print array[1];}'`
			do
				so_objs[$so]=$so
				report "$so"
			done
			report ""
		done
	elif [ -e "$target" ] ; then
		bin=$target
			target_output_dir=bin
			if [ `file -L $bin | grep -i -c "shared object" ` == 1 ] ; then
				target_output_dir=lib
			fi

			if [ `file -L $bin | grep -c ELF` != 1 ] ; then
				report "<Skip> $bin"
				if [ ! -z "$PATH_OUTPUT" ] ; then
					cp $bin $PATH_OUTPUT/$target_output_dir
				fi
				continue
			fi
			echo "[Add] $bin: "
			bin_name=`basename $bin`
			if [ "$target_output_dir" == "lib" ] ; then
				so_objs[$bin_name]=$bin_name
			fi
			if [ ! -z "$PATH_OUTPUT" ] ; then
				cp $bin $PATH_OUTPUT/$target_output_dir
				if [ ! -z "$PATH_BIN_STRIP" ] ; then
					$PATH_BIN_STRIP $PATH_OUTPUT/$target_output_dir/$bin_name
				fi
			fi
			for so in `$PATH_BIN_READELF -a $bin | grep Shared | awk -F'[' '{split($2,array,"]"); print array[1];}'`
			do
				so_objs[$so]=$so
				report "$so"
			done
			report ""

		bin_dirname=`dirname $bin`
		if [ -d "$bin_dirname/../lib" ] ; then
			if [ -z ${lib_dirs["$bin_dirname/../lib"]} ] ; then
				lib_dirs["$bin_dirname/../lib"]=$bin_dirname/../lib
				if [ -z "$TARGET_LIBRARY_CHECK" ] ; then
					TARGET_LIBRARY_CHECK="$bin_dirname/../lib"
				else
					TARGET_LIBRARY_CHECK="$bin_dirname/../lib $TARGET_LIBRARY_CHECK"
				fi
			fi
		fi
	fi
done
IFS=' ' read -ra LIB_DIR <<< "$TARGET_LIBRARY_CHECK"
echo "[INFO] Check shared library dir: ${LIB_DIR[@]}"
while [ ${#so_objs[@]} -gt 0 ]
do
	flag_size=${#so_objs[@]}
	for so_checker in "${so_objs[@]}"
	do
		so_path=
		echo -n "."
		for lib_dir in "${LIB_DIR[@]}"
		do
			if [ -r "$lib_dir/$so_checker" ]; then
				so_path=$lib_dir/$so_checker

				if [ ! -z "$PATH_OUTPUT" ] ; then
					if [ `echo $lib_dir | grep -c "sysroot" ` == 1 ] ; then
						report "use slib:$so_checker"
						cp $so_path $PATH_OUTPUT/slib
						if [ ! -z $PATH_BIN_STRIP ] ; then
							$PATH_BIN_STRIP $PATH_OUTPUT/slib/$so_checker
						fi
					else
						report "use lib:$so_checker"
						cp $so_path $PATH_OUTPUT/lib
						if [ ! -z $PATH_BIN_STRIP ] ; then
							$PATH_BIN_STRIP $PATH_OUTPUT/lib/$so_checker
						fi
					fi 			
				fi
				break
			fi
		done
		if [ -z $so_path ] ; then
			echo "[NOT_FOUND] : $so_checker"
			exit 1
		else
			report "$so_checker: $so_path"
			for so in `$PATH_BIN_READELF -a $so_path | grep Shared | awk -F'[' '{split($2,array,"]"); print array[1];}'`
			do
				so_objs[$so]=$so
			done
		fi
	done
	echo -n "*"
	if [ "${flag_size}" -eq "${#so_objs[@]}" ] ; then
		echo
		echo -e "All:\n\t ${so_objs[@]}"
		break
	fi
done
