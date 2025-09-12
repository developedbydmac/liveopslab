# Incident Response Runbook

## **ITIL Incident Management Process**

This runbook follows ITIL best practices for incident management in the LiveOps Lab environment.

### **Incident Classification**

| Priority | Severity | Business Impact | Response Time | Example |
|----------|----------|-----------------|---------------|---------|
| **P1 - Critical** | Complete service failure | Business-critical systems down | 15 minutes | Total outage, data corruption |
| **P2 - High** | Major feature unavailable | Significant user impact | 1 hour | Authentication failure, DB connection loss |
| **P3 - Medium** | Minor feature issues | Limited user impact | 4 hours | Performance degradation, non-critical alerts |
| **P4 - Low** | Cosmetic issues | Minimal impact | Next business day | UI glitches, documentation errors |

---

## **Incident Response Workflow**

### **1. Detection & Logging**
- **Alert Sources**: Prometheus alerts, Grafana notifications, user reports
- **Incident Logging**: Create ticket in incident management system
- **Initial Assessment**: Determine severity and impact scope

### **2. Acknowledgment & Assignment**
- **Acknowledge Alert**: Stop alert escalation
- **Assign Engineer**: Based on severity and expertise required
- **Communication**: Notify stakeholders of incident

### **3. Investigation & Diagnosis**
- **Gather Data**: Review dashboards, logs, and metrics
- **Isolate Issue**: Identify affected components
- **Root Cause Analysis**: Determine underlying cause

### **4. Resolution & Recovery**
- **Implement Fix**: Apply solution or workaround
- **Test Resolution**: Verify service restoration
- **Monitor Recovery**: Ensure stability post-fix

### **5. Closure & Documentation**
- **Incident Closure**: Confirm resolution with stakeholders
- **Postmortem**: Schedule review for P1/P2 incidents
- **Knowledge Base**: Update runbooks and documentation

---

## **Escalation Matrix**

### **On-Call Rotation**

| Level | Role | Escalation Time | Responsibilities |
|-------|------|-----------------|------------------|
| **L1** | Operations Engineer | Immediate | Initial response, basic troubleshooting |
| **L2** | Senior Engineer | 15 min (P1), 30 min (P2) | Advanced troubleshooting, code fixes |
| **L3** | Engineering Manager | 30 min (P1), 1 hour (P2) | Resource coordination, external escalation |
| **L4** | CTO/VP Engineering | 1 hour (P1) | Executive decision making |

### **Contact Information**

```
L1 On-Call: +1-555-0100 (PagerDuty)
L2 On-Call: +1-555-0200 (PagerDuty)
Engineering Manager: +1-555-0300
Infrastructure Team: #ops-alerts (Slack)
```

---

## **Common Incident Scenarios**

### **High Latency Alerts**

**Symptoms:**
- API response time > 2 seconds
- Database query time > 500ms
- User complaints about slow performance

**Investigation Steps:**

1. **Check Application Metrics**
   ```bash
   # Review Grafana dashboard: "Application Performance"
   # Key metrics: response_time_p95, active_connections, CPU usage
   ```

2. **Database Analysis**
   ```sql
   -- Check for long-running queries
   SELECT query, query_start, state, wait_event_type 
   FROM pg_stat_activity 
   WHERE state = 'active' AND query_start < now() - interval '30 seconds';
   
   -- Check for table locks
   SELECT * FROM pg_locks WHERE NOT granted;
   ```

3. **Infrastructure Review**
   - EC2 instance CPU/memory utilization
   - RDS performance insights
   - CloudWatch metrics

**Resolution Options:**
- **Short-term**: Scale up instances, optimize slow queries
- **Long-term**: Add read replicas, implement caching, optimize database schema

---

### **Error Rate Spike**

**Symptoms:**
- HTTP 5xx errors > 1% of requests
- Exception alerts from application
- User reports of failures

**Investigation Steps:**

1. **Application Logs Review**
   ```bash
   # Check recent error logs
   tail -f /var/log/app/error.log | grep -E "(ERROR|CRITICAL)"
   
   # Search for specific error patterns
   grep "ConnectionError\|TimeoutError" /var/log/app/app.log
   ```

2. **Recent Deployments**
   - Check deployment history
   - Review recent code changes
   - Verify configuration changes

3. **External Dependencies**
   - API endpoint health checks
   - Third-party service status pages
   - Network connectivity tests

**Resolution Options:**
- **Immediate**: Rollback recent deployment
- **Mitigation**: Implement circuit breakers, retry logic
- **Fix**: Apply hotfix for identified bugs

---

### **Memory Usage Critical**

**Symptoms:**
- Memory utilization > 90%
- OOMKilled processes
- Application crashes

**Investigation Steps:**

1. **Process Analysis**
   ```bash
   # Check memory usage by process
   ps aux --sort=-%mem | head -10
   
   # Monitor real-time memory usage
   top -o %MEM
   
   # Check for memory leaks
   valgrind --tool=memcheck --leak-check=full ./your-app
   ```

2. **Application Profiling**
   - Review memory allocation patterns
   - Check for unclosed connections
   - Analyze garbage collection logs

**Resolution Options:**
- **Immediate**: Restart affected services, scale up instances
- **Short-term**: Implement memory limits, optimize memory usage
- **Long-term**: Code review and memory leak fixes

---

### **Disk Space Critical**

**Symptoms:**
- Disk usage > 85%
- Write failures
- Application errors related to disk space

**Investigation Steps:**

1. **Disk Usage Analysis**
   ```bash
   # Check disk usage
   df -h
   
   # Find largest directories
   du -sh /* | sort -hr | head -10
   
   # Find large files
   find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null
   ```

2. **Log File Review**
   ```bash
   # Check log sizes
   ls -lah /var/log/
   
   # Clean old logs (if safe)
   find /var/log -name "*.log" -mtime +7 -exec rm {} \;
   ```

**Resolution Options:**
- **Immediate**: Clean log files, remove temporary files
- **Short-term**: Implement log rotation, increase disk size
- **Long-term**: Automated cleanup scripts, monitoring thresholds

---

## **Communication Templates**

### **Incident Notification (P1/P2)**

```
🚨 INCIDENT ALERT - P[X] - [BRIEF_DESCRIPTION]

Status: INVESTIGATING
Start Time: [TIMESTAMP]
Impact: [AFFECTED_SERVICES]
Estimated Users Affected: [NUMBER]

Current Actions:
- [ACTION_1]
- [ACTION_2]

Next Update: [TIME]

Incident Commander: [NAME]
```

### **Status Update**

```
📊 INCIDENT UPDATE - P[X] - [BRIEF_DESCRIPTION]

Status: [INVESTIGATING/MITIGATING/RESOLVED]
Duration: [TIME_ELAPSED]

Progress:
✅ [COMPLETED_ACTIONS]
🔄 [IN_PROGRESS_ACTIONS]
⏳ [PLANNED_ACTIONS]

ETA to Resolution: [ESTIMATE]
Next Update: [TIME]
```

### **Resolution Notice**

```
✅ INCIDENT RESOLVED - P[X] - [BRIEF_DESCRIPTION]

Status: RESOLVED
Total Duration: [TIME]
Root Cause: [BRIEF_EXPLANATION]

Resolution:
- [RESOLUTION_STEPS]

Monitoring:
- Service restored at [TIME]
- Performance metrics normal
- No user impact detected

Postmortem: [LINK_TO_POSTMORTEM]
```

---

## **Post-Incident Actions**

### **Immediate (Within 24 hours)**
- [ ] Confirm complete service restoration
- [ ] Update stakeholders on resolution
- [ ] Create initial incident summary
- [ ] Schedule postmortem meeting (P1/P2 only)

### **Short-term (Within 1 week)**
- [ ] Complete detailed postmortem
- [ ] Identify action items and owners
- [ ] Update runbooks and procedures
- [ ] Implement immediate fixes

### **Long-term (Within 1 month)**
- [ ] Execute improvement action items
- [ ] Review and update monitoring
- [ ] Conduct training if needed
- [ ] Update incident response procedures

---

## **Tools & Resources**

### **Monitoring & Dashboards**
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093

### **Communication Channels**
- **Slack**: #incident-response
- **Email**: oncall@liveopslab.com
- **Phone**: PagerDuty escalation

### **Documentation**
- **Runbooks**: `/docs/runbooks/`
- **Architecture**: `/docs/architecture.md`
- **Playbooks**: `/docs/playbooks/`

### **Log Locations**
```
Application Logs: /var/log/app/
System Logs: /var/log/syslog
Web Server: /var/log/nginx/
Database: /var/log/postgresql/
```

---

## **Continuous Improvement**

### **Monthly Reviews**
- Incident volume and trends
- MTTR (Mean Time To Recovery) analysis
- Alert effectiveness review
- Process improvement opportunities

### **Quarterly Actions**
- Update contact information
- Review escalation procedures
- Conduct tabletop exercises
- Update tool configurations

### **Annual Planning**
- Disaster recovery testing
- Business continuity planning
- Capacity planning review
- Training program updates

---

*For questions about this runbook, contact the Platform Engineering team.*
