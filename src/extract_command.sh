inspect_args

ROM_FILE=$(realpath "${args[rom]}")
OUTPUT_DIR="${args[output]}"

set +e # bleh

is_ifd_rom() {
	filetype=$(file -b $1)
	[[ $filetype = "Intel serial flash for PCH ROM" ]]
}

is_fmap_rom() {
	grep -obUaP "__FMAP__" $1 &> /dev/null
	[[ $? = 0 ]]
}

is_cbfs_rom() {
	cbfstool $1 print &> /dev/null
	[[ $? = 0 ]]
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
	if is_ifd_rom $ROM_FILE; then
		echo "ROM contains an Intel Flash Descriptor"
		mkdir -p $OUTPUT_DIR/regions/ifd
		pushd $OUTPUT_DIR/regions/ifd > /dev/null
		ifdtool -x $ROM_FILE &> /dev/null
		ls | fmt -s | sed "s/^/[IFD] /"
		popd > /dev/null
		echo
	fi
	if is_fmap_rom $ROM_FILE; then
		echo "ROM contains a coreboot FMAP"
		regions=$(cbfstool novacustom_v56x_mtl_v0.9.0.rom layout -w \
		    | grep \' \
		    | cut -d \' -f 2 \
		    | grep -v -e "SI_ALL" -e "SI_BIOS" -e "RW_SECTION_A" -e "RW_SECTION_B" -e "RW_MISC" -e "UNIFIED_MRC_CACHE" -e "RW_SHARED" -e "WP_RO" -e "RO_SECTION"
		    )
		mkdir -p $OUTPUT_DIR/regions/fmap
		pushd $OUTPUT_DIR/regions/fmap > /dev/null
		for region in $regions; do
			echo "[FMAP] $region.bin"
			cbfstool $ROM_FILE read -r $region -f $region.bin
			if is_cbfs_rom $region.bin; then
				echo "Region contains a CBFS"
				mkdir -p $region.cbfs
				cbfs_files=$(cbfstool $ROM_FILE print -r $region | cut -d ' ' -f 1 | tail -n +3 | grep -v "(empty)")
				pushd $region.cbfs > /dev/null
				for file in $cbfs_files; do
					echo "  [CBFS] $file"
					cbfstool $ROM_FILE extract -r $region -f $(echo $file | tr \/ -) -n $file -m x86 &> /dev/null # TODO FIXME etc
				done
				popd > /dev/null
			fi
		done
		popd > /dev/null
		echo
	fi
}

main
