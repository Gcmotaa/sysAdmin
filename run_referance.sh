  GNU nano 8.4                                                                                               run_reference.sh                                                                                                         
#!/bin/bash
set -e

echo "=== Running Reference (Single Disk) Benchmarks ==="
echo "Make sure your .fio profile files are currently set to your reference disk (e.g., filename=/dev/sdb)."
read -p "Press Enter to start..."

mkdir -p /root/fio/results/reference
PROFILES=("seq-write" "seq-read" "rand-write" "rand-read")

for profile in "${PROFILES[@]}"; do
    for i in {1..3}; do
        echo "Running reference -> $profile (Attempt $i)..."
        sudo fio --output-format=json "/root/fio/${profile}.fio" > "/root/fio/results/reference/${profile}-run${i}.json"
    done
done

echo "=== Reference Benchmarks Complete! ==="
echo "Next step: Update your .fio profile files to point to filename=/dev/md0, then run script 2."




