# SPDX-FileCopyrightText: 2024 3mdeb Sp. z o. o.
#
# SPDX-License-Identifier: MIT

ROM1_FILE=$(realpath "${args[rom1]}")
ROM2_FILE=$(realpath "${args[rom2]}")
OUTPUT_DIR="${args[output]}"

WORKDIR=/tmp/romscope

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

	pushd $WORKDIR > /dev/null
	files=$(cat a/manifest \
		| cut -d ' ' -f 2 \
		| grep -v -e "regions/fmap/FW_MAIN_A.bin" -e "regions/fmap/FW_MAIN_B.bin" -e "regions/fmap/COREBOOT.bin" -e "regions/fmap/VBLOCK_A.bin" -e "regions/fmap/VBLOCK_B.bin" -e "regions/fmap/GBB.bin" -e "regions/ifd/flashregion" \
		)
	files_match=1
	for file in $files; do
		if ! diff a/$file b/$file > /dev/null; then
			files_match=0
			echo "Generating report for $file"
			diffoscope a/$file b/$file --html $(echo $file | tr \/ -).html &> /dev/null
		fi
	done
	vblocks=$(cat a/manifest \
		| cut -d ' ' -f 2 \
		| grep -e "regions/fmap/VBLOCK_A.bin" -e "regions/fmap/VBLOCK_B.bin" -e "regions/fmap/GBB.bin" \
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

	if [ $files_match -eq 1 ]; then
		if [ $vblocks_match -ne 1 ]; then
			echo "Files match but signatures differ. Binaries are likely signed using different Vboot keys."
		else
			echo "All signatures match."
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
