inspect_args

ROM_FILE=$(realpath "${args[rom]}")
OUTPUT_DIR="${args[output]}"

# Checks if a ROM is an Intel-style binary with flash descriptor.
is_ifd_rom() {
	filetype=$(file -b $ROM_FILE)
	[[ $filetype = "Intel serial flash for PCH ROM" ]]
}

main() {
	if [ ! -f $ROM_FILE ]; then
		echo "File $ROM_FILE does not exist. Please input a valid ROM file path."
		return 1
	fi
	if [ -z "$OUTPUT_DIR" ]; then
		OUTPUT_DIR=$ROM_FILE.extracted
	fi
	mkdir -p $OUTPUT_DIR
	if is_ifd_rom; then
		echo "File is an Intel-style ROM with descriptor. Extracting IFD subregions."
		mkdir -p $OUTPUT_DIR/regions/ifd
		pushd $OUTPUT_DIR/regions/ifd > /dev/null
		ifdtool -x $ROM_FILE &> /dev/null
		echo "Extracted regions:"
		ls | fmt -s | sed "s/^/[IFD] /"
		popd > /dev/null
	fi
}

main
