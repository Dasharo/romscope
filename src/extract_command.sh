# SPDX-FileCopyrightText: 2024 3mdeb Sp. z o. o.
#
# SPDX-License-Identifier: MIT

ROM_FILE=$(realpath "${args[rom]}")
OUTPUT_DIR="${args[output]}"

rom_extract $ROM_FILE $OUTPUT_DIR
