# Administração de Sistemas (2026/2027) — Project Checklist

**Deadline:** December 4, 2026, at 17:30  
**Submission:** Google Form (Group number, student IDs, names of 3 members, and PDF report)

---

## Phase 1: Infrastructure & Identity Setup (Labs 4–7)
- [x] **SSH & Machine Access:** Set up SSH keys and `~/.ssh/config` via `ads-entrada` to connect to `rocky` (`10.10.10.3`), `openmediavault` (`10.10.10.4`), and `desktop` (`10.10.10.6`), and access `windows` (`10.10.10.5`) via Proxmox/port 8006.
- [ ] **Hardware & System Inventory (Report Table):** Document OS versions, DNS settings, CPU/RAM (`nproc`, `free -h`), and system vs. data disks (`lsblk`) for all four VMs.
- [x] **NTP & Network Verification:** Verify `chronyc tracking` / `timedatectl` (within Kerberos's 5-minute tolerance) and inter-VM connectivity across all 4 machines.
- [x] **FreeIPA Server (`rocky`):** Install and configure FreeIPA (`GROUP36.LAN`) with LDAP, Kerberos, DNS, and CA, with `SELinux` enforcing.
- [x] **IPA Client Enrollment (`desktop`):** Join `desktop` to `GROUP36.LAN` using `ipa-client-install` and configure DNS to point to `10.10.10.3`.
- [X] **IPA Client Enrollment (`openmediavault`):** Point DNS to `10.10.10.3` and enroll `openmediavault` as an IPA client (`ipa-client-install`).
- [ ] **Windows Kerberos Integration (`windows`):** Point DNS to `10.10.10.3`, configure `ksetup` for realm `GROUP36.LAN`, and map Kerberos login acco  unts.
- [x] **Test User Creation:** Create user `ana` (`ipa user-add ana`) and initialize her password on `rocky`.

---

## Phase 2: Destructive Storage Experiments (Before Final RAID)
- [x] **UC1 — RAID Benchmarking (`fio`):**
  - [x] Run 3-repetition `fio` benchmarks (`--direct=1`, `seq-read`, `seq-write`, `rand-read`, `rand-write`) across `reference`, `raid0`, `raid1`, `raid5`, `raid6`, `raid10`, `raid5-degraded`, and `raid5-rebuild`.
  - [x] Export the 96 JSON result files to `Very-Tuf` and generate summary tables and plots (MB/s and IOPS).
  - [ ] **Choose & Justify RAID Level:** Select the final RAID level for `openmediavault` based on MB/s, IOPS, usable capacity, fault tolerance, and hypervisor shared-storage analysis.
- [ ] **UC2 — Disk Failure & Reconstruction:**
  - [ ] Configure `mdadm-monitor` to trigger a local email or script alert on disk failure.
  - [ ] With `ana`'s home mounted and actively being written to on `desktop`, fail a disk (`mdadm --fail`), verify the hot spare activates automatically, and record rebuild time.
  - [ ] Fail additional disks until the array fails completely and document the impact on client mounts, `/proc/mdstat`, `mdadm --detail`, and system logs.

---

## Phase 3: Production Storage, Shares & Automount
- [ ] **Final RAID & LVM (`openmediavault`):** Build the chosen RAID array (`/dev/md0` + spare if applicable), create volume group `vg_data` and logical volume `lv_homes`, and mount at `/srv/homes`.
- [ ] **NFSv4 + Kerberos (`openmediavault`):** Export `/srv/homes` to `10.10.10.0/28` with `rw,sec=krb5p,root_squash,no_subtree_check`.
- [ ] **SMB3 + Kerberos (`openmediavault`):** Configure Samba to share `/srv/homes` over SMB3 with Kerberos authentication on the same underlying directory.
- [ ] **FreeIPA Automount Maps (`rocky`):** Configure `auto.master` and `auto.home` maps in FreeIPA so `/home/<user>` mounts automatically from `openmediavault` via NFSv4 (`krb5p`).
- [ ] **Client Auto-Mounting:**
  - [ ] Configure `autofs` + SSSD on `desktop` to mount `/home/<user>` from FreeIPA maps on login.
  - [ ] Configure `windows` so `H:` maps automatically to `\\openmediavault\homes` via SMB3 without re-prompting for credentials.

---

## Phase 4: Security, Directory Lifecycle & Backup Use Cases
- [ ] **UC3 — NFS Security & Firewall:**
  - [ ] Create temporary export `/srv/teste` with `sec=sys` and demonstrate root UID spoofing from `desktop`.
  - [ ] Test `sec=krb5`, `krb5i`, and `krb5p` to confirm access requires a valid Kerberos ticket (even for `desktop` `root`).
  - [ ] Capture port `2049` traffic with `tcpdump` for each security flavor and verify in Wireshark which modes expose `notas.txt` contents.
  - [ ] Verify `root_squash`, `/etc/exports` subnet restriction, and `nftables` rules (allowing `2049/tcp` only from `10.10.10.0/24`), then remove `/srv/teste`.
  - [ ] Benchmark one `fio` profile over NFS for `sys`, `krb5`, and `krb5p` to measure encryption/integrity overhead.
- [ ] **UC4 — Account Lifecycle, HBAC & Sudo:**
  - [ ] Create `alunos` and `docentes` groups in FreeIPA, add `ana` to `alunos`, and configure HBAC rules (`alunos` → `desktop` only; `docentes` → all hosts).
  - [ ] Create a FreeIPA `sudo` rule granting `docentes` sudo privileges on `desktop` without touching local `/etc/sudoers`.
  - [ ] Change `ana`'s password on `windows` (`Ctrl+Alt+Del`) and verify immediate login on `desktop`.
  - [ ] Disable and re-enable `ana` in FreeIPA and capture login/denial logs in `journalctl` (`desktop`) and KDC logs (`rocky`).
- [ ] **UC5 — Backup & Disaster Recovery (`restic` + `rclone`):**
  - [ ] Authorize Google Drive (`rclone authorize "drive"`), configure remote `gdrive`, save repo password in `/root/.restic-pass` (and offline), and run `restic init` on `rclone:gdrive:ads-backup`.
  - [ ] Configure a daily `systemd` timer for `restic backup /srv/homes` and a retention policy (`restic forget --prune`).
  - [ ] Simulate accidental deletion of `notas.txt`, locate it via `restic find`, and restore it with original ownership/permissions.
  - [ ] Run `restic check`, destroy the RAID array (`mdadm --stop` + `--zero-superblock`), rebuild RAID + LVM, restore `/srv/homes` from Google Drive, and measure total recovery time (RTO).

---

## Phase 5: End-to-End Verification & Final Report
- [ ] **Section 4 End-to-End Test:**
  - [ ] Create `ana` on `rocky` and assign her to `alunos`.
  - [ ] Log into `desktop` as `ana`, verify automatic NFSv4 `krb5p` home mount, and create `notas.txt`.
  - [ ] Log into `windows` as `ana@GROUP36.LAN`, verify `H:` SMB3 mount, append a line to `notas.txt`, and confirm visibility on `desktop` and ownership by `ana` on `openmediavault`.
  - [ ] Fail one disk on `openmediavault` (`mdadm --fail`) and confirm the spare rebuilds transparently without interrupting `ana`.
  - [ ] Disable `ana` (`ipa user-disable ana`) and verify login and home mounting fail on both `desktop` and `windows`.
- [ ] **PDF Report & Submission:**
  - [ ] Compile architecture overview, Lab 4 table, justified decisions, config files, and command/log evidence for **UC1–UC5** (including RPO/RTO and encryption/privacy analysis for UC5).
  - [ ] Leave all 4 VMs configured and running, and submit the PDF report with group/member details via the Google Form.