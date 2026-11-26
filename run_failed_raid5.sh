#!/bin/bash
set -e

DISKS=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
FAIL_DISK="${DISKS[3]}"
PROFILES=("seq-write" "seq-read" "rand-write" "rand-read")
DEG_DIR="/root/fio/results/raid5-degraded"
REB_DIR="/root/fio/results/raid5-rebuild"

echo "=== RAID 5 Degraded & Rebuild Benchmark (UC1d) ==="
echo "Target array: /dev/md0 | Disk to fail/rebuild: $FAIL_DISK"
echo "Make sure your .fio profiles use filename=/dev/md0."
read -p "Press Enter to start..."

mkdir -p "$DEG_DIR" "$REB_DIR"

# 1. Create a 4-disk RAID 5 array and wait for initial sync
sudo mdadm --create /dev/md0 --level=5 --raid-devices=4 "${DISKS[@]}"

echo "Waiting for initial RAID 5 synchronization to finish..."
while grep -q -E "resync|recovery" /proc/mdstat; do
    cat /proc/mdstat
    sleep 5
done

# 2. Degraded mode: fail one disk and run profiles (3x each)
echo "Marking $FAIL_DISK as failed (degraded mode)..."
sudo mdadm --manage /dev/md0 --fail "$FAIL_DISK"
cat /proc/mdstat

for profile in "${PROFILES[@]}"; do
    for i in {1..3}; do
        echo "Running raid5-degraded -> $profile (Attempt $i)..."
        sudo fio --output-format=json "/root/fio/${profile}.fio" > "$DEG_DIR/${profile}-run${i}.json"
    done
done

# 3. Rebuild mode: remove failed disk, re-add it, and run fio while reconstructing
echo "Removing $FAIL_DISK and re-adding to trigger reconstruction..."
sudo mdadm --manage /dev/md0 --remove "$FAIL_DISK"
sudo mdadm --manage /dev/md0 --add "$FAIL_DISK"
sleep 5

for profile in "${PROFILES[@]}"; do
    for i in {1..3}; do
        if grep -q "recovery" /proc/mdstat; then
            echo "Recovery active -> Running raid5-rebuild -> $profile (Attempt $i)..."
            sudo fio --output-format=json "/root/fio/${profile}.fio" > "$REB_DIR/${profile}-run${i}.json"
        else
            echo "Note: Recovery finished before $profile (Attempt $i); running post-rebuild check..."
            sudo fio --output-format=json "/root/fio/${profile}.fio" > "$REB_DIR/${profile}-run${i}-post.json"
        fi
    done
done

echo "Waiting for reconstruction to finish completely..."
while grep -q -E "resync|recovery" /proc/mdstat; do
    cat /proc/mdstat
    sleep 5
done

# 4. Teardown array and zero superblocks
echo "Tearing down /dev/md0 and zeroing superblocks..."
sudo mdadm --stop /dev/md0
sudo mdadm --zero-superblock "${DISKS[@]}"

echo "=== RAID 5 Degraded & Rebuild Benchmark Complete! ==="