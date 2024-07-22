ROM1_FILE=$(realpath "${args[rom1]}")
ROM2_FILE=$(realpath "${args[rom2]}")
OUTPUT_DIR="${args[output]}"

WORKDIR=/tmp/romscope

main () {
	if [ -e $WORKDIR ]; then
		rm -r $WORKDIR
	fi

	echo "Extracting file $ROM1_FILE"
	mkdir -p $WORKDIR/a
	rom_extract $ROM1_FILE $WORKDIR/a > /dev/null
	pushd $WORKDIR/a > /dev/null
	find regions -type f -exec printf '%s\n' {} + > manifest
	popd > /dev/null

	echo "Extracting file $ROM2_FILE"
	mkdir -p $WORKDIR/b
	rom_extract $ROM2_FILE $WORKDIR/b > /dev/null
	pushd $WORKDIR/b > /dev/null
	find regions -type f -exec printf '%s\n' {} + > manifest
	popd > /dev/null

	pushd $WORKDIR > /dev/null
	files=$(cat a/manifest \
		| grep -v -e "regions/fmap/FW_MAIN_A.bin" -e "regions/fmap/FW_MAIN_B.bin" -e "regions/fmap/COREBOOT.bin" -e "regions/fmap/VBLOCK_A.bin" -e "regions/fmap/VBLOCK_B.bin" -e "regions/ifd/flashregion" \
		)
	for file in $files; do
		echo "Generating report for $file"
		diffoscope a/$file b/$file --html $(echo $file | tr \/ -).html &> /dev/null
	done
	popd > /dev/null

	if [ -z "$OUTPUT_DIR" ]; then
	 	OUTPUT_DIR="report"
	fi
	mkdir -p $OUTPUT_DIR
	cp $WORKDIR/*.html $OUTPUT_DIR/
	echo "Report placed in folder: '$OUTPUT_DIR'"

	rm -r $WORKDIR
}

main
