#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Compression Functions
# Everything EngineScript compresses (database backups, site archives, configuration backups,
# the dump before a MariaDB update) is zstd: level 3 on one thread, so a backup leaves the other
# CPUs to the sites. On a 600 MB database that took 10 s instead of gzip's 47 s, and the file was
# 2% smaller. Backups made before 2026-11-20 and archives from the EngineScript Site Exporter
# plugin (PHP has no zstd) are gzip, so everything that reads one takes either, by its name.
# Loaded by enginescript-common.sh and enginescript-site-archive.sh.
#----------------------------------------------------------------------------------


# The tar option that writes a zstd archive with the settings above: tar "${ES_TAR_ZSTD}" -cf ...
# shellcheck disable=SC2034  # used by the scripts that source this file
ES_TAR_ZSTD="--use-compress-program=zstd -q -3 -T1"

# Compress standard input to standard output
# Usage: <command> | es_compress > <file>.zst
function es_compress() {
    zstd -q -3 -T1 -c
}

# Write a file's contents, decompressed, to standard output. The name says how: .zst or .gz.
# Usage: es_decompress <file>
function es_decompress() {
    case "$1" in
        *.zst) zstd -q -dc -- "$1" ;;
        *.gz) gzip -dc -- "$1" ;;
        *) echo "Not a .zst or .gz file: $1" >&2; return 1 ;;
    esac
}

# Decompress standard input to standard output, for data stored under a name ending in .zst or .gz
# Usage: <command> | es_decompress_stream <name>
function es_decompress_stream() {
    case "$1" in
        *.zst) zstd -q -dc ;;
        *.gz) gzip -dc ;;
        *) echo "Not a .zst or .gz name: $1" >&2; return 1 ;;
    esac
}

# Print the tar option that reads an archive stored under a name ending in .tar.zst or .tar.gz
# Usage: tar "$(es_tar_read_option <name>)" -tf <file>
function es_tar_read_option() {
    case "$1" in
        *.tar.zst) echo "--zstd" ;;
        *.tar.gz) echo "--gzip" ;;
        *) echo "Not a .tar.zst or .tar.gz name: $1" >&2; return 1 ;;
    esac
}

# Succeed when a compressed file reads back whole (.zst or .gz)
# Usage: es_compressed_file_ok <file>
function es_compressed_file_ok() {
    case "$1" in
        *.zst) zstd -q -t -- "$1" 2> /dev/null ;;
        *.gz) gzip -t -- "$1" 2> /dev/null ;;
        *) return 1 ;;
    esac
}
