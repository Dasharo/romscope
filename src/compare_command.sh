# SPDX-FileCopyrightText: 2024 3mdeb Sp. z o. o.
#
# SPDX-License-Identifier: MIT

ROM1_FILE=$(realpath "${args[rom1]}")
ROM2_FILE=$(realpath "${args[rom2]}")
OUTPUT_DIR="${args[output]}"

WORKDIR=/tmp/romscope

is_km_file() {
	[ -f "$1" ] && ! cmp --quiet --bytes="$(stat --printf %s "$1")" /dev/zero "$1"
}

find_file() {
	cat a/manifest b/manifest | cut -d ' ' -f 2 | grep -e "$1" | sort -u
}

stage() {
	echo "===== $1 ====="
}

main () {
	if [ -e $WORKDIR ]; then
		rm -r $WORKDIR
	fi

	if [ ! -f "$ROM1_FILE" ]; then
		echo "File $ROM1_FILE does not exist. Please input a valid ROM file path."
		return 1
	fi

	if [ ! -f "$ROM2_FILE" ]; then
		echo "File $ROM2_FILE does not exist. Please input a valid ROM file path."
		return 1
	fi

	stage Preparation

	echo "Extracting file $ROM1_FILE"
	mkdir -p $WORKDIR/a
	rom_extract $ROM1_FILE $WORKDIR/a > /dev/null
	pushd $WORKDIR/a > /dev/null
	file_list="$(find regions -type f -exec printf '%s\n' {} +)"
	for file_entry in $file_list; do
		echo $(sha256sum $file_entry) >> manifest
	done
	popd > /dev/null

	echo "Extracting file $ROM2_FILE"
	mkdir -p $WORKDIR/b
	rom_extract $ROM2_FILE $WORKDIR/b > /dev/null
	pushd $WORKDIR/b > /dev/null
	file_list="$(find regions -type f -exec printf '%s\n' {} +)"
	for file_entry in $file_list; do
		echo $(sha256sum $file_entry) >> manifest
	done
	popd > /dev/null

	stage Comparison

	pushd $WORKDIR > /dev/null
	ibg_key_change=0
	ibg_mixed_provisioning=0
	extra_excludes=
	km_file=$(find_file "regions/fmap/COREBOOT.cbfs/key_manifest.bin")
	if [ -n "$km_file" ]; then
		# Key Manifest has the following structure:
		#  1. 12 bytes
		#  2. 2 bytes specifying offset to KM's signature (OFFSET)
		#  3. `OFFSET - 12` bytes that end with a list of hashes, including hash
		#     of BPM's public key
		#  4. KM's signature
		#
		# 1-3 should be the same for identical keys unless some options have
		# changed as well.  4 can differ for the same IBG key used twice.
		#
		# Not checking if b/ has a different key offset, as we'll be comparing
		# offsets as well.
		sig_offset=$(xxd -s12 -p -l2 "a/$km_file")
		sig_offset=0x${sig_offset:2}${sig_offset:0:2}

		is_km_a=$(is_km_file "a/$km_file"; echo $?)
		is_km_b=$(is_km_file "b/$km_file"; echo $?)
		if [ "$is_km_a" -ne 0 ] || [ "$is_km_b" -ne 0 ]; then
			if [ "$is_km_a" -ne "$is_km_b" ]; then
				ibg_mixed_provisioning=1
			fi
		elif cmp --quiet --bytes="$sig_offset" "a/$km_file" "b/$km_file"; then
			echo "IBG keys match."
		else
			echo "IBG keys differ."
			ibg_key_change=1
		fi

		# Avoiding reporting changes in these files if at least one image is
		# IBG-enabled.
		extra_excludes+=" -e regions/fmap/COREBOOT.cbfs/boot_policy_manifest.bin"
		extra_excludes+=" -e regions/fmap/COREBOOT.cbfs/key_manifest.bin"
	fi
	si_me=$(find_file "regions/fmap/SI_ME.bin")
	if [ -n "$si_me" ]; then
		# Check if the length of a mismatched range is small enough to likely
		# indicate a key change rather than an ME update.  Resigning IBG-enabled
		# binaries with the same IBG but different Vboot keys results results in
		# changing ME as well, hence this is not predicated on $ibg_key_change.
		#
		# `cmp -l` lists mismatching offsets and byte values, the length is
		# computed as difference between the last and first offsets plus one.
		# The threshold may need to be updated in the future.
		if [ "$(cmp -l "a/$si_me" "b/$si_me" | wc -l)" -le 1024 ]; then
			# Avoid reporting ME as modified in this case.
			extra_excludes+=" -e regions/fmap/SI_ME.bin"
		fi
	fi
	popd > /dev/null

	pushd $WORKDIR > /dev/null
	files=$(cat a/manifest b/manifest \
		| cut -d ' ' -f 2 \
		| grep -v -e "regions/fmap/FW_MAIN_A.bin" \
		          -e "regions/fmap/FW_MAIN_B.bin" \
		          -e "regions/fmap/COREBOOT.bin" \
		          -e "regions/fmap/VBLOCK_A.bin" \
		          -e "regions/fmap/VBLOCK_B.bin" \
		          -e "regions/fmap/GBB.bin" \
		          -e "regions/ifd/flashregion" \
		          $extra_excludes \
		| sort -u
		)
	files_match=1
	different=
	for file in $files; do
		# Creating missing file to get the diff.
		if [ ! -e a/$file ]; then
			touch a/$file
		elif [ ! -e b/$file ]; then
			touch b/$file
		fi

		if ! diff a/$file b/$file > /dev/null; then
			files_match=0
			different+=" $file"

			echo "Generating report for $file"
			diffoscope a/$file b/$file --html $(echo $file | tr \/ -).html &> /dev/null
		fi
	done
	vblocks=$(cat a/manifest b/manifest \
		| cut -d ' ' -f 2 \
		| grep -e "regions/fmap/VBLOCK_A.bin" \
		       -e "regions/fmap/VBLOCK_B.bin" \
		       -e "regions/fmap/GBB.bin" \
		| sort -u
		)
	vblocks_match=1
	for vblock in $vblocks; do
		if diff a/$vblock b/$vblock > /dev/null; then
			echo "Vblock $vblock matches."
		else
			vblocks_match=0
			echo "Vblock $vblock differs."
		fi
	done
	popd > /dev/null

	stage Conclusions

	if [ "$ibg_mixed_provisioning" -eq 1 ]; then
		echo "Only one of the binaries seems to be provisioned for IBG."
	elif [ "$ibg_key_change" -eq 1 ]; then
		echo "Binaries are provisioned with different IBG keys."
	fi

	if [ $files_match -eq 1 ]; then
		if [ $vblocks_match -ne 1 ]; then
			echo "Files match but Vboot signatures differ. Binaries are likely signed using different Vboot keys."
		else
			echo "No file differences were detected."
		fi
	else
		echo "Not all files match. Check report for detailed information."
		if [ -z "$OUTPUT_DIR" ]; then
			OUTPUT_DIR="report"
		fi
		mkdir -p $OUTPUT_DIR
		cp $WORKDIR/*.html $OUTPUT_DIR/
		echo "Report placed in folder: '$OUTPUT_DIR'"
	fi

	rm -r $WORKDIR
}

main
