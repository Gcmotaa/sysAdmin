!/bin/bash
set -e

# Define your data disks and profiles
DISKS=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
PROFILES=("seq-write" "seq-read" "rand-write" "rand-read")

echo "=== Starting RAID Benchmarks (UC1) ==="
echo "Make sure your .fio profile files are currently set to filename=/dev/md0."
read -p "Press Enter to start..."

# Helper function for RAID tests
run_raid_test() {
    local raid_name="$1"
    local create_cmd="$2"
    
    echo "========================================="
    echo "=== Setting up: $raid_name ==="
    echo "========================================="
    mkdir -p "/root/fio/results/$raid_name"
    
    # Create array
    eval "$create_cmd"
    
    # Wait for initial synchronization to finish
    echo "Waiting for RAID synchronization to finish..."
    while grep -q -E "resync|recovery" /proc/mdstat; do
        cat /proc/mdstat
        sleep 5
    done
    echo "Synchronization complete for $raid_name."
    
    # Run benchmarks
    for profile in "${PROFILES[@]}"; do
        for i in {1..3}; do
            echo "Running $raid_name -> $profile (Attempt $i)..."
            sudo fio --output-format=json "/root/fio/${profile}.fio" > "/root/fio/results/$raid_name/${profile}-run${i}.json"
        done
    done
    
    # Teardown array and wipe superblocks between levels
    echo "Tearing down $raid_name..."
    sudo mdadm --stop /dev/md0
    sudo mdadm --zero-superblock "${DISKS[@]}"
    sleep 2
}

# --- 1. RAID 0 (4 disks) ---
run_raid_test "raid0" "sudo mdadm --create /dev/md0 --level=0 --raid-devices=4 ${DISKS[0]} ${DISKS[1]} ${DISKS[2]} ${DISKS[3]}"

# --- 2. RAID 1 (2 disks) ---
run_raid_test "raid1" "sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 ${DISKS[0]} ${DISKS[1]}"

# --- 3. RAID 5 (3 active + 1 spare) ---
run_raid_test "raid5" "sudo mdadm --create /dev/md0 --level=5 --raid-devices=3 ${DISKS[0]} ${DISKS[1]} ${DISKS[2]} --spare-devices=1 ${DISKS[3]}"

# --- 4. RAID 6 (4 disks) ---
run_raid_test "raid6" "sudo mdadm --create /dev/md0 --level=6 --raid-devices=4 ${DISKS[0]} ${DISKS[1]} ${DISKS[2]} ${DISKS[3]}"

# --- 5. RAID 10 (4 disks) ---
run_raid_test "raid10" "sudo mdadm --create /dev/md0 --level=10 --raid-devices=4 ${DISKS[0]} ${DISKS[1]} ${DISKS[2]} ${DISKS[3]}"

echo "=== All RAID Benchmarks Completed Successfully! ==="
