ROM_FILE=$(realpath "${args[rom]}")
OUTPUT_DIR="${args[output]}"

rom_extract $ROM_FILE $OUTPUT_DIR
