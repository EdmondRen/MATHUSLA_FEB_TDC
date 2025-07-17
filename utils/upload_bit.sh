### CHANGE TO YOUR board ADDRESS
export red_address=192.168.1.8

bit_load() {
    local dir="${1:-.}"  # Default to current directory if not specified
    local files file_count selected_index selected_file

    # Find all .bit files (up to 20 for safety)
    mapfile -t files < <(find "$dir" -maxdepth 3 -type f -name '*.bit' | sort | head -n 20)
    file_count=${#files[@]}

    if [[ $file_count -eq 0 ]]; then
        echo "No .bit files found in '$dir'."
        return 1
    fi

    echo "Found $file_count .bit file(s):"
    for i in "${!files[@]}"; do
        printf "  [%d] %s\n" "$((i+1))" "${files[$i]}"
    done

    while true; do
        read -p "Select a file to use [1-$file_count] (or 0 to cancel): " selected_index
        if [[ "$selected_index" =~ ^[0-9]+$ ]] && (( selected_index >= 0 && selected_index <= file_count )); then
            break
        else
            echo "Invalid input. Please enter a number between 1 and $file_count, or 0 to cancel."
        fi
    done

    if (( selected_index == 0 )); then
        echo "Operation cancelled."
        return 1
    fi

    selected_file="${files[$((selected_index-1))]}"
    echo "Selected file: $selected_file"
    ls -lth "$selected_file"
    read -p "Proceed with this file? [y/N] " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Confirmed: $selected_file"

            # Now send the file to red pitaya
            filenew="${selected_file%.bit}.bif"
            filebin="${selected_file}.bin"
            echo all:{ $selected_file } > $filenew
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