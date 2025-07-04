### CHANGE TO YOUR board ADDRESS
export red_address=192.168.1.8

bit_load() {
    local dir="${1:-.}"  # Default to current directory if not specified
    local file

    # Find the first .bit file (non-recursively), ignoring hidden files
    file=$(find "$dir" -maxdepth 3 -type f -name '*.bit' | sort | head -n 1)

    if [[ -z "$file" ]]; then
        echo "No .bit files found in '$dir'."
        return 1
    fi

    # Prompt user
    echo "Found file: $file"
    ls -lth $file
    read -p "Is this the file you want to use? [y/N] " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Confirmed: $file"

            # Now send the file to red pitaya
            filenew="${file%.bit}.bif"
            filebin="${file}.bin"
            echo all:{ $file } > $filenew
            bootgen -image $filenew -arch zynq -process_bitstream bin -o $filebin -w
            scp $filebin root@$red_address:/root/temp.bin
            ssh root@$red_address -t '/opt/redpitaya/bin/fpgautil -b /root/temp.bin'
            ;;
        *)
            echo "File not selected."
            return 1
            ;;
    esac
}

bit_reset() {
    ssh root@$red_address -t 'overlay.sh v0.94'
}