# DevOps Foundation Week 4: Thursday Reflection

## Question 1: Ansible vs Bash Idempotency

### The Declarative State Engine
Ansible replaces fragile imperative Bash guard conditionals (like `id kk-api || useradd`) by using a **declarative state management model**. Instead of executing step-by-step instructions, Ansible modules use Python code under the hood to perform system discovery, checking the current target environment against the target state defined in your playbook before touching anything.

### Mechanics of `ansible.builtin.user`
When the `ansible.builtin.user` module executes with `state: present`, it queries the system's database files (such as `/etc/passwd` and `/etc/group`). It evaluates whether the user exists, matches the specified group (`service_group`), and uses the correct parameters (like `/usr/sbin/nologin`). If the account matches perfectly, it returns `ok` and skips the step. If it finds a mismatch, it makes the specific system adjustments and returns `changed`.

### The Failure Mode of the Shell Module
If you use `ansible.builtin.shell: useradd kk-api`, Ansible loses its intelligence. The shell module blindly runs the raw string payload inside a subshell on every pass. On the first pass, it builds the user. On the second pass, the raw `useradd` command executes again, collides with the existing user, and crashes the playbook with an exit code 9 user-already-exists failure. 

Using the `shell` module forces you back into writing manual, hardcoded bash wrappers, completely breaking the clean, predictable, and idempotent design patterns of modern configuration management tools.


## Question 2: Handler Behaviour Under Parallel Execution

### Execution Across Multiple Hosts
If the unit file template task triggers a `changed` state on host A and host B, but returns an `ok` state on host C, the `Restart service` handler will run exactly **two times in total** across your infrastructure. Ansible processes hosts in parallel, but tracks execution paths independently. It will trigger the handler once on host A and once on host B, while host C skips it completely.

### Multiple Tasks Notifying a Single Handler
If two separate configuration tasks both notify the exact same handler, and both change on the same host during a run, that handler will execute exactly **one time** on that host.

### The Governing Rules of Handlers
This behavior is controlled by two fundamental Ansible runtime rules:
1. **Deduplication:** Handlers are added to a global execution queue per host. If a handler is notified multiple times by different tasks, Ansible deduplicates the entries so it only appears in the queue once.
2. **End-of-Play Execution:** Handlers do not run immediately when a task changes. Instead, they are held and executed at the very end of the `tasks` block, after all main playbook stages have finished.

This approach prevents unnecessary service restarts and avoids application flapping. If you change a configuration template and a systemd permission mask in the same run, Ansible consolidates those events into a single, clean service restart at the end of the deployment cycle.


## Question 3: The Terraform to Ansible Inventory Bridge

### Approach A: The Local State Parsing Strategy
The first automation strategy uses the Terraform state file directly. By using the `terraform_remote_state` data source or executing the `json` state exporter (`terraform output -json`), we can pipe live IPs out of our infrastructure engine. In Ansible, this is managed by using the `cloud.terraform.terraform_provider` dynamic inventory plugin, which reads your local or remote state files and builds an internal memory map of your server hosts on the fly.

### Approach B: The Cloud Provider API Strategy
The second strategy relies on cloud provider APIs and metadata tracking. By assigning tags or labels to your instances inside your HCL code (for example, setting `labels = { env = "staging", tier = "backend" }` on your Multipass or cloud virtual instances), you can use a dynamic inventory plugin like `community.general.multipass` or `amazon.aws.aws_ec2`. This plugin queries the live infrastructure API at runtime, grouping servers based on their active tags regardless of whether their underlying IP addresses have changed.

### Architectural Tradeoffs
* **State Parsing:** This approach is fast and does not require external access keys, but it introduces a strict dependency: you must run `terraform apply` before Ansible can discover anything. If your state file gets corrupted or desynchronized, your automation pipeline breaks.
* **Provider API:** This method is highly resilient and queries the actual running environment, but it requires active API access keys and adds network overhead because it queries external APIs before every playbook run.

### Team Recommendation
For the KijaniKiosk team of three engineers, I strongly recommend the **State Parsing Strategy (using Terraform Outputs)**. Since the team is already using a centralized remote state backend with MinIO, extracting IPs using a local output script or a lightweight dynamic inventory plugin provides a secure, self-contained pipeline. It eliminates the need to manage extra API credentials across three developer machines while keeping your infrastructure and configuration steps tightly coupled.


## Question 4: Configuration Drift in the Ansible Model

### Drift Detection Mechanics
Unlike Terraform, which continuously audits resources against a state file, standard Ansible does not have an automated `plan` command that alerts you to drift out of the box. Instead, drift detection in Ansible happens **inline during runtime execution**. It scans your target servers at runtime, compares their live values against your playbook configuration, and reports any discrepancies as a system change.

### The Result of Manual Modifications
If an engineer logs into the `payments` server by hand and modifies the local firewall rules, nothing happens until the next automation cycle. When you run `ansible-playbook` again, the `community.general.ufw` module will scan the active rules on the server, catch the manual alteration, and automatically overwrite it to restore your declarative security baseline. The task will log a yellow `changed: [payments-staging]` status in your terminal, proving that drift correction took place.

### Architectural Divergence
The core architectural difference comes down to **State Enforcement vs. Lifecycle Ownership**:
* **Terraform** manages the lifecycle of your infrastructure. It tracks everything in a state file and will forcefully delete untracked resources to make the live environment match your code.
* **Ansible** evaluates only the specific tasks you explicitly define in your playbook. It is completely blind to any other configurations on the machine.

### Operational Implications
Because Ansible doesn't track global state, if an engineer manually creates a completely new, untracked user account or installs an unmanaged package on the server, Ansible will completely ignore it unless a task explicitly checks for it. For the KijaniKiosk team, this means Ansible cannot guarantee absolute protection against configuration drift across the entire operating system. To ensure complete security compliance, the team must run playbooks on a regular, automated schedule (using tools like cron or a CI/CD runner) to continuously audit and align system states.

