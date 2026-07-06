# DevOps Foundation Week 4: Wednesday Reflection

## Question 1: The Module Boundary Decision

### The Reasoning Behind the Current Boundary
Keeping networking resources (VPC, Subnets, Gateways) in the root module while isolating compute elements inside the `app_server` module follows the **Lifecycle Decoupling Principle**. 

Core networking is foundational, long-lived, and slow-moving infrastructure. Application servers are ephemeral, dynamic, and fast-moving. By establishing this boundary, we ensure that scaling, destroying, or refactoring application servers never risks mutating or destabilizing the foundational network topology routing tables.

### Extracting Networking into Separate Modules
It makes sense to extract networking into an independent module when building a **Shared Platform Engineering Framework**. In corporate environments, a single networking module is maintained by a specialized NetSec team to stamp out identical, standardized VPC fabrics across multiple business units (e.g., Prod-VPC, Dev-VPC, Staging-VPC).

### Risks of Monolithic Infrastructure Modules
Combining network and compute into a single, tightly coupled module creates catastrophic risk:
* **Blast Radius Amplification:** A simple structural adjustment to a server subnet mask could trigger a cascading destructive replacement of the entire network fabric.
* **Targeted Destruction Disasters (`terraform destroy -target`):** If a developer runs a targeted destroy command against a networking module component, the cloud provider will fail or forcefully cascade the deletion to any dependent resources. Because the VMs live *inside* the subnets being targeted, the hypervisor engine will forcefully tear down and terminate all running application VMs to clear the network interfaces, resulting in catastrophic state loss and unmitigated application downtime.


## Question 2: for_each Removal Behaviour

### Adding "cache" to a for_each Mapping Workspace
When you append a new key-value element `"cache"` to the `servers` map inside a `for_each` loop configuration, the lifecycle operates as follows:
1. **`terraform plan`:** Terraform parses the tracking state and identifies that three named indices already exist (`module.app_servers["api"]`, `module.app_servers["payments"]`, `module.app_servers["logs"]`). It detects exactly one unmapped key in the configuration: `module.app_servers["cache"]`. The plan output will display exactly: **`Plan: 1 to add, 0 to change, 0 to destroy.`**
2. **`terraform apply`:** Terraform leaves the three active production servers completely untouched. It opens a isolated API execution call to provision only the new `"cache"` host. No service disruption or resource modification occurs on existing systems.

### The Contrast with `count` Index Shifting
If the infrastructure had been provisioned using a sequential indexing array like `count = 3` (evaluating indices `0, 1, 2`) and scaled to `count = 4`:
* Adding a resource to the *end* of the array functions similarly to `for_each`. 
* **The Index Renumbering Disaster:** However, if you need to *remove* or *insert* an item in the middle of a `count` array (e.g., removing index `1`), Terraform's addressing system breaks. Because it addresses elements strictly by integer position (`aws_instance.server[1]`), removing an internal item forces every subsequent resource to shift down an index position. 

Terraform will interpret this index reordering as a complete configuration change for all shifted resources. It will attempt to **destroy and recreate every shifted server instance** to align them with the new index numbers, causing massive, unnecessary production downtime. `for_each` completely prevents this risk by mapping assets to immutable string keys instead of volatile list integers.
## Question 3: State as a Team Artefact

### Concurrency and Remote State Locking Mechanics
When Amina executes `terraform apply`, Terraform contacts the remote MinIO S3 backend and secures an exclusive **State Lock** (typically managed via a distributed lock table or backend object lock mechanism). 

If Tendo runs `terraform plan` at the exact same millisecond:
* **Amina's apply succeeds** because her client successfully acquired the lock first.
* **Tendo's plan fails immediately** with a `State Lock Error`. 

The lock error output contains critical diagnostic metadata, including the **Lock ID**, the **Operation Type** (e.g., `apply`), the **User/Host Identity** (Amina's local machine/username information), and the **Acquisition Timestamp**. This allows Tendo to instantly identify who owns the active mutation lock and estimate when the state engine will release it.

### Mid-Run Crash Recovery Procedure
If Amina's workstation suffers a catastrophic power failure midway through an active apply, leaving two servers provisioned but the local runtime dead before updating the state file, the system is left in an **Orphaned Out-of-Sync State**. 

The correct engineering recovery procedure follows these precise steps:
1. **Clear the Stale Lock:** The remote backend will likely still show the state as locked by Amina's crashed process. Once her terminal is back online, manually unlock the state using the Lock ID found in the error logs:
   ```bash
   terraform force-unlock <LOCK_ID>
Re-synchronize State with Reality (refresh): Run a refresh command to instruct Terraform to query the active virtualization providers and pull the live state of any partially built resources into the tracking file:

Bash
terraform refresh
Inspect the Drift Margin: Run terraform state list to see what resources were successfully saved. If the two built servers are missing from the state file because the crash happened before a write cycle, use terraform import to manually bind the live hypervisor resource IDs back to their corresponding HCL addresses:

Bash
terraform import 'module.app_servers["api"].null_resource.this' <actual-vm-id>
Execute Safe Convergence: Run a fresh terraform plan to verify that the delta matches reality perfectly, then run terraform apply to cleanly resume building the missing infrastructure elements.
```
## Question 4: What Three Provisioned VMs Cannot Do

### Architectural Separation of Concerns
The division between **Provisioning (Terraform)** and **Configuration Management (Ansible)** reflects the architectural separation between the **Fabric Layer** and the **Runtime Layer**. 

Terraform's core design pattern is *Declarative Orchestration of Cloud Resources*. Its internal engine communicates with external cloud APIs to allocate virtualized hardware, storage volumes, and network boundaries. It does not possess a deep, native awareness of the internal kernel structures, package managers, or user-space software running inside the operating system. Managing software internals directly inside Terraform violates the Single Responsibility Principle and creates brittle infrastructure code.

### Installing Nginx via Raw Terraform (Without Ansible)
To force-install Nginx using only Terraform resources, you would have to embed an inline provisioner scripts block directly within your resource definition:

```hcl
resource "null_resource" "this" {
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install nginx -y",
      "sudo systemctl start nginx"
    ]
  }
}```
Tradeoffs of the Raw Provisioner Approach vs. Ansible
While using raw remote-exec blocks works for simple, one-shot setups, it quickly breaks down when scaling infrastructure due to major design tradeoffs:

Lack of Idempotency: Raw bash scripts inside a remote-exec block run blindly from top to bottom every time they are triggered. If the script fails halfway through, re-running it can corrupt configurations or throw errors. Ansible tasks are inherently idempotent, meaning they check the current state of the system first and only execute if a change is actually required.

Brittle Error Handling: If an apt mirror times out during a Terraform run, the entire infrastructure build fails and halts mid-way. Ansible decouples this risk by separating your infrastructure code from your application configuration code.

Zero State Maintenance: Terraform provisioners do not track the health of internal software configuration files after the initial creation step. If someone accidentally stops Nginx manually inside the VM later, Terraform will report 0 changes on the next run. Ansible continuously audits and enforces the internal state of your servers, making it the superior choice for scaling and maintaining complex software configurations.

