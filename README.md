# romscope

A tool for comparing coreboot firmware binaries.

## Usage

```bash
$ ./romscope
romscope - A tool for comparing firmware binaries

Usage:
  romscope COMMAND
  romscope [COMMAND] --help | -h
  romscope --version | -v

Commands:
  extract   Extract subregions from a firmware binary
  compare   Compare two binaries
```

### Extract

The `extract` command decomposes a coreboot binary into files. You can
optionally specify an output directory.

```bash
$ ./romscope extract coreboot.rom coreboot.extracted
ROM contains an Intel Flash Descriptor
[IFD] flashregion_0_flashdescriptor.bin
[IFD] flashregion_1_bios.bin
[IFD] flashregion_2_intel_me.bin
[IFD] flashregion_3_gbe.bin

ROM contains a coreboot FMAP
[FMAP] SI_DESC.bin
[FMAP] SI_GBE.bin
[FMAP] SI_ME.bin
[FMAP] VBLOCK_A.bin
[FMAP] FW_MAIN_A.bin
Region contains a CBFS
  [CBFS] fallback/payload
  [CBFS] fallback/romstage
  [CBFS] cpu_microcode_blob.bin
  [CBFS] fallback/ramstage
  [CBFS] config
  [CBFS] revision
  [CBFS] build_info
  [CBFS] fallback/dsdt.aml
  [CBFS] ec.rom
  [CBFS] vbt.bin
  [CBFS] fspm.bin
  [CBFS] fsps.bin
  [CBFS] fallback/postcar
[...]
```

### Compare

Use `compare` to compare two different coreboot firmware binaries. For example,
to compare a release candidate with the final release binary:

```bash
$ ./romscope compare v560tu.rom novacustom_v56x_mtl_v0.9.0.rom
Extracting file /home/michal/Development/Dasharo/romscope/v560tu.rom
Extracting file /home/michal/Development/Dasharo/romscope/novacustom_v56x_mtl_v0.9.0.rom
Generating report for regions/fmap/SI_DESC.bin
Generating report for regions/fmap/SI_GBE.bin
Generating report for regions/fmap/SI_ME.bin
Generating report for regions/fmap/FW_MAIN_A.cbfs/fallback-payload
[...]
Report placed in folder: 'report'
```

You can optionally specify an output directory. By default, the reports are
placed in a folder named `reports` in the current working directory.

## Dependencies

- cbfstool
- ifdtool
- diffoscope

## License

This program is licensed under the [MIT License](../LICENSES/MIT.txt).
