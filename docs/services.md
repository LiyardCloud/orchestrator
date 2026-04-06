# Service Registry

Every service must register its port here to avoid conflicts.

| Service      | Port | URL                               | Notes                         |
| ------------ | ---- | --------------------------------- | ----------------------------- |
| gateway      | 8080 | (all subdomains)                  | Entry point — all traffic here |
| dataroom-api | 5001 | api-dataroom.liyard.cloud         | Internal only via gateway     |
| journal      | 5002 | journal.liyard.cloud              | Internal only via gateway     |
