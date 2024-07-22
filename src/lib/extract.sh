## Add any function here that is needed in more than one parts of your
## application, or that you otherwise wish to extract from the main function
## scripts.
##
## Note that code here should be wrapped inside bash functions, and it is
## recommended to have a separate file for each function.
##
## Subdirectories will also be scanned for *.sh, so you have no reason not
## to organize your code neatly.
##

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

rom_extract() {
	set +e # bleh

	rom_file=$1
	output_dir=$2
	if [ ! -f $rom_file ]; then
		echo "File $rom_file does not exist. Please input a valid ROM file path."
		return 1
	fi
	if [ -z "$output_dir" ]; then
		output_dir=$rom_file.extracted
	fi
	mkdir -p $output_dir
	if is_ifd_rom $rom_file; then
		echo "ROM contains an Intel Flash Descriptor"
		mkdir -p $output_dir/regions/ifd
		pushd $output_dir/regions/ifd > /dev/null
		ifdtool -x $rom_file &> /dev/null
		ls | fmt -s | sed "s/^/[IFD] /"
		popd > /dev/null
		echo
	fi
	if is_fmap_rom $rom_file; then
		echo "ROM contains a coreboot FMAP"
		regions=$(cbfstool $rom_file layout -w \
		    | grep \' \
		    | cut -d \' -f 2 \
		    | grep -v -e "SI_ALL" -e "SI_BIOS" -e "RW_SECTION_A" -e "RW_SECTION_B" -e "RW_MISC" -e "UNIFIED_MRC_CACHE" -e "RW_SHARED" -e "WP_RO" -e "RO_SECTION"
		    )
		mkdir -p $output_dir/regions/fmap
		pushd $output_dir/regions/fmap > /dev/null
		for region in $regions; do
			echo "[FMAP] $region.bin"
			cbfstool $rom_file read -r $region -f $region.bin
			if is_cbfs_rom $region.bin; then
				echo "Region contains a CBFS"
				mkdir -p $region.cbfs
				cbfs_files=$(cbfstool $rom_file print -r $region | cut -d ' ' -f 1 | tail -n +3 | grep -v "(empty)")
				pushd $region.cbfs > /dev/null
				for file in $cbfs_files; do
					echo "  [CBFS] $file"
					cbfstool $rom_file extract -r $region -f $(echo $file | tr \/ -) -n $file -m x86 &> /dev/null # TODO FIXME etc
				done
				popd > /dev/null
			fi
		done
		popd > /dev/null
		echo
	fi
}
