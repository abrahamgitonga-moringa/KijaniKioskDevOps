# Week 3 Post-Mortem Engineering Reflection Matrix

## Question 1: Requirement Conflicts and Integration Resolution
During the implementation phase, I discovered a clear conflict between Requirement 2 (Achieving a Hardening Score Below 2.5 via Read-Only Isolation) and Requirement 3 (Ensuring Log Rotation Access Survival). 

Enforcing ProtectSystem=strict locks the entire filesystem into read-only mode, which immediately caused the payment service to fail because it couldn't append to its log file (/opt/kijanikiosk/shared/logs/payments.log). 

To resolve this conflict, I introduced a targeted exception rule using the systemd directive:
ReadWritePaths=/opt/kijanikiosk/shared/logs/

This opened a tightly scoped write path through the read-only sandbox. This taught me that infrastructure security cannot be treated as a collection of isolated tasks. Security controls and operational requirements interact directly, and real-world system engineering requires carefully balancing protection levels against application runtime needs.

---

## Question 2: Technical Translation Bridge (Nia to Tendo Mapping)
* Corporate Governance Statement (Nia Text): "Privilege Escalation Interception ensures that system processes cannot inherit higher processing access permissions than their starting assignment, completely neutralizing system breakout threats."
* Systems Engineering Translation (Tendo Text): "Enforcing NoNewPrivileges=true and clearing the CapabilityBoundingSet= bitmask restricts the service execution path from using the execve() system call to transition into setuid binaries, neutralizing local execution exploits."

### Architectural Translation Trade-offs
The translation from corporate language to systems engineering details shifts the focus entirely:
* What is Lost: We lose high-level business context and clear explanations of risk impact. A non-technical stakeholder cannot determine how a bitmask adjustment prevents financial platform disruption.
* What is Gained: We gain absolute technical precision. Tendo's formulation provides an engineer with actionable implementation steps, mapping the rule directly to explicit kernel parameters, execution boundaries, and system behavior.

---

## Question 3: Infrastructure Vulnerability Matrix and Environment Fragility
The most fragile component of the provisioning script is the programmatic firewall parsing engine and its dependency on explicit rule ordering. 

If the server is deployed to an upstream cloud environment where network packets are pre-filtered by an external provider, or if local networking structures use alternative routing layouts, our local rule mapping rule logic can break:
ufw allow on lo to any port 3001

To make this section highly robust across diverse production tiers, we need to gather specific network parameters from the target environment before running the script:
1. The exact network device name configurations (e.g., eth0 vs. ens3).
2. The precise IP subnets used by our monitoring infrastructure.
3. Information on whether upstream cloud firewalls are active, allowing us to coordinate security policies seamlessly across both the host machine and the cloud network border.
