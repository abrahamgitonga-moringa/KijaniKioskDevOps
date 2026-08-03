# Technical Demo Script: Automated Blue/Green Traffic Switching & Rollback

## Objective
Demonstrate zero-downtime deployment, health verification, and sub-90-second automated rollback capabilities of the KijaniKiosk deployment pipeline.

## Demo Sequence

### Phase 1: Verify Active Baseline State
```bash
# Verify active environment and running service
cat /opt/kijanikiosk/.active-env
curl -s [http://127.0.0.1:80/health](http://127.0.0.1:80/health) | jq .
Narrative: "Notice how Nginx is actively routing live traffic to the Blue environment serving version v1.3.0."

Phase 2: Zero-Downtime Traffic Switch to Green
Bash
# Switch active traffic to Green (v1.4.0)
sudo bash /opt/kijanikiosk/scripts/switch-env.sh green
curl -s [http://127.0.0.1:80/health](http://127.0.0.1:80/health) | jq .
Narrative: "We execute switch-env.sh green. The script validates Green health on port 3001, rewrites the Nginx upstream config, and reloads Nginx gracefully. Live requests now receive v1.4.0 with zero dropped connections."

Phase 3: Post-Deployment Monitoring & Automated Rollback
Bash
# Terminal 1: Start confidence monitor
sudo bash /opt/kijanikiosk/scripts/post-deploy-monitor.sh 60

# Terminal 2: Inject failure
sudo systemctl stop kk-api-green.service
Narrative: "With traffic on Green, we simulate a critical backend failure. The post-deployment monitor detects 3 consecutive 502 responses and instantly invokes automated rollback without human intervention."

Phase 4: Verification of Recovery
Bash
cat /opt/kijanikiosk/.active-env
curl -s [http://127.0.0.1:80/health](http://127.0.0.1:80/health) | jq .
Narrative: "Total recovery time was 16 seconds (well within our 90-second SLA target). Active traffic is back on the stable Blue release (v1.3.0)."


---

## Now Moving to Kubernetes & Containers (Requirement 6)

Now we begin building your production container image and verifying its specs on your terminal!

### Step 4: Create Docker Configuration Files

1. Create `deployment-pipeline/containers/Dockerfile.production`:

```dockerfile
# Multi-stage build for minimal production image
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx tsc

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -g 1001 nodejs && adduser -u 1001 -G nodejs nodejs
COPY package*.json ./
RUN npm ci --only=production
COPY --from=builder /app/dist ./dist
USER nodejs
EXPOSE 3001
CMD ["node", "dist/index.js"]
