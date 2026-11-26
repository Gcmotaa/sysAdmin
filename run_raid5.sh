#!/bin/bash
set -euo pipefail

DISKS=("/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde")
FAIL_DISK="${DISKS[3]}"
PROFILES=("seq-write" "seq-read" "rand-write" "rand-read")

NORM_DIR="/root/fio/results/raid5"
DEG_DIR="/root/fio/results/raid5-degraded"
REB_DIR="/root/fio/results/raid5-rebuild"

run_profile_suite() {
    local out_dir="$1"
    local label="$2"

    for profile in "${PROFILES[@]}"; do
        for i in {1..3}; do
            if [[ "$label" == "raid5-rebuild" ]] && ! grep -q "recovery" /proc/mdstat; then
                echo "Note: Recovery finished before ${profile} (Attempt ${i}); saving as post-rebuild..."
                sudo fio --output-format=json "/root/fio/${profile}.fio" > "${out_dir}/${profile}-run${i}-post.json"
            else
                echo "Running ${label} -> ${profile} (Attempt ${i})..."
                sudo fio --output-format=json "/root/fio/${profile}.fio" > "${out_dir}/${profile}-run${i}.json"
            fi
        done
    done
}

echo "=== RAID 5 Full Benchmark (Healthy, Degraded & Rebuild) ==="
echo "Target array: /dev/md0 | Disk to fail/rebuild: $FAIL_DISK"
echo "Make sure your .fio profiles use filename=/dev/md0."
read -p "Press Enter to start..."

mkdir -p "$NORM_DIR" "$DEG_DIR" "$REB_DIR"

# 1. Create a 4-disk RAID 5 array and wait for initial sync
sudo mdadm --create /dev/md0 --level=5 --raid-devices=4 "${DISKS[@]}"

echo "Waiting for initial RAID 5 synchronization to finish..."
while grep -q -E "resync|recovery" /proc/mdstat; do
    cat /proc/mdstat
    sleep 5
done

# 2. Healthy RAID 5 mode: run profiles (3x each)
echo "=== Phase 1/3: Healthy RAID 5 ==="
cat /proc/mdstat
run_profile_suite "$NORM_DIR" "raid5"

# 3. Degraded mode: fail one disk and run profiles (3x each)
echo "=== Phase 2/3: Degraded RAID 5 ==="
echo "Marking $FAIL_DISK as failed (degraded mode)..."
sudo mdadm --manage /dev/md0 --fail "$FAIL_DISK"
cat /proc/mdstat
run_profile_suite "$DEG_DIR" "raid5-degraded"

# 4. Rebuild mode: remove failed disk, re-add it, and run fio while reconstructing
echo "=== Phase 3/3: Rebuild RAID 5 ==="
echo "Removing $FAIL_DISK and re-adding to trigger reconstruction..."
sudo mdadm --manage /dev/md0 --remove "$FAIL_DISK"
sudo mdadm --manage /dev/md0 --add "$FAIL_DISK"
sleep 5
run_profile_suite "$REB_DIR" "raid5-rebuild"

echo "Waiting for reconstruction to finish completely..."
while grep -q -E "resync|recovery" /proc/mdstat; do
    cat /proc/mdstat
    sleep 5
done

# 5. Teardown array and zero superblocks
echo "Tearing down /dev/md0 and zeroing superblocks..."
sudo mdadm --stop /dev/md0
sudo mdadm --zero-superblock "${DISKS[@]}"

echo "=== All 3 RAID 5 Benchmarks Complete! ==="