| Máquina          | Nome       | IP         | Sistema e versão           | CPU | RAM | Discos(num: size)  |
| ---------------- | ---------- | ---------- | -------------------------- | --- | --- | ------------------ |
| rocky            | fred       | 10.10.10.3 | Rocky linux 9.8            | 2   | 2   | 1: 32              |
| openmediavault   | shaggy     | 10.10.10.4 | Debian linux 13.7          | 2   | 2   | 1: 32, 4:16        |
| windows          | velma      | 10.10.10.5 | Windows 11 Enterprise 24H2 | 2   | 8   | 1: 32              |
| desktop          | daphne     | 10.10.10.6 | Ubuntu 26.04.1 LTS         | 2   | 4   | 1: 32              |

Started by running the benchmarks and then installing chrony to sync every system to rocky(except windows cuz i cant get it to smart. 8GB windows 11 lmao).


UC1
reference raid0 and raid1 benchmarks were taken in a different day from raid5, raid6 and raid10. unusual values between the 2 sets may be due to that difference

chrony was installed for synchronization.

freeIPA on rocky done: configured dns server. 
freeIPA on desktop done.
need to chose raid level
