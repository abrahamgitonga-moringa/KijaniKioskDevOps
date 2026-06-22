# Engineering Decision: /usr/sbin/nologin vs /bin/false

### Choice Made
All KijaniKiosk system service accounts (`kk-api`, `kk-payments`, `kk-logs`) are configured to use `/usr/sbin/nologin` as their operational shell.

### Mechanism and Behavioral Distinction
* **`/bin/false`**: This is a binary that immediately returns an exit status code of `1` (failure) upon execution. When a user with this shell attempts to authenticate, the connection drops instantly without displaying any contextual information to the client.
* **`/usr/sbin/nologin`**: This is a polite, interactive program that outputs a clean, customizable message to standard output (`This account is currently not available.`) before exiting with a non-zero status code.

### Architectural Reason for Choice
While both options successfully block interactive shell sessions (such as SSH or terminal logins), `/usr/sbin/nologin` is selected because it produces explicit log events via `syslog` and provides immediate clarity during debugging. If a configuration error or malicious script attempts an interactive login under a service context, `/usr/sbin/nologin` reports the event gracefully to system diagnostics. 

Furthermore, these shells prevent terminal access while keeping the underlying UID fully functional for background daemons, systemd task invocations, and POSIX file system checks.
