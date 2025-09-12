# Post-Incident Review (Postmortem) Template

**Incident ID:** [INC-YYYY-XXXX]  
**Date:** [YYYY-MM-DD]  
**Duration:** [START_TIME] - [END_TIME] ([TOTAL_DURATION])  
**Severity:** [P1/P2/P3/P4]  
**Incident Commander:** [NAME]  
**Postmortem Author:** [NAME]  

---

## **Executive Summary**

*Brief 2-3 sentence overview of the incident, impact, and resolution.*

[SUMMARY_TEXT]

---

## **Incident Details**

### **What Happened?**
*Detailed description of the incident sequence*

- **Initial Detection:** [TIME] - [HOW_DETECTED]
- **Root Cause:** [TECHNICAL_CAUSE]
- **Impact Scope:** [AFFECTED_SYSTEMS/USERS]
- **Resolution:** [HOW_RESOLVED]

### **Timeline of Events**

| Time (UTC) | Event | Action Taken | Owner |
|------------|-------|--------------|-------|
| 14:23 | Alert: High error rate detected | Acknowledged alert | @engineer1 |
| 14:25 | Investigation started | Checked application logs | @engineer1 |
| 14:30 | Root cause identified | Database connection pool exhausted | @engineer1 |
| 14:32 | Mitigation applied | Restarted application services | @engineer2 |
| 14:35 | Service restored | Confirmed error rate normalized | @engineer1 |
| 14:45 | Monitoring confirmed | All metrics within normal range | @engineer1 |

### **Impact Assessment**

**User Impact:**
- **Users Affected:** [NUMBER] ([PERCENTAGE]% of total users)
- **Services Affected:** [LIST_OF_SERVICES]
- **Business Impact:** [REVENUE/REPUTATION/OPERATIONAL_IMPACT]

**Technical Impact:**
- **Error Rate:** Peak [X]% (normal: <0.1%)
- **Latency:** Peak [X]ms (normal: [X]ms)
- **Availability:** [X]% during incident (SLA: [X]%)

---

## **Root Cause Analysis**

### **Contributing Factors**

**Primary Cause:**
[DETAILED_TECHNICAL_EXPLANATION]

**Contributing Factors:**
1. [FACTOR_1]
2. [FACTOR_2]
3. [FACTOR_3]

### **Why Did This Happen?**

**5-Whys Analysis:**

1. **Why did the service fail?**
   - [ANSWER_1]

2. **Why did [ANSWER_1] occur?**
   - [ANSWER_2]

3. **Why did [ANSWER_2] happen?**
   - [ANSWER_3]

4. **Why did [ANSWER_3] occur?**
   - [ANSWER_4]

5. **Why did [ANSWER_4] happen?**
   - [ROOT_CAUSE]

### **What Worked Well?**

✅ **Successes:**
- Fast detection (alert fired within [X] minutes)
- Clear escalation path followed
- Effective communication to stakeholders
- Quick identification of root cause
- [OTHER_SUCCESSES]

---

## **What Didn't Work**

❌ **Failures:**
- [FAILURE_1]
- [FAILURE_2]
- [FAILURE_3]

❌ **Detection Issues:**
- Alert fatigue reduced response time
- Insufficient monitoring of [COMPONENT]
- [OTHER_DETECTION_ISSUES]

❌ **Response Issues:**
- Unclear ownership of [COMPONENT]
- Missing runbook for this scenario
- [OTHER_RESPONSE_ISSUES]

---

## **Action Items**

### **Immediate Actions** (Completed)
- [x] **[DATE]** - Service restored and monitoring confirmed normal
- [x] **[DATE]** - Stakeholders notified of resolution
- [x] **[DATE]** - Emergency fix deployed

### **Short-term Actions** (1-2 weeks)

| Action | Owner | Due Date | Status |
|--------|-------|----------|---------|
| Implement connection pool monitoring | @engineer1 | 2024-01-15 | 🔄 In Progress |
| Add database connection alerts | @engineer2 | 2024-01-20 | ⏳ Planned |
| Update runbook with new procedures | @engineer1 | 2024-01-18 | ⏳ Planned |

### **Medium-term Actions** (1-3 months)

| Action | Owner | Due Date | Priority |
|--------|-------|----------|----------|
| Implement database connection pooling resilience | @team-backend | 2024-02-15 | High |
| Add automated failover for database connections | @team-platform | 2024-03-01 | Medium |
| Conduct chaos engineering tests for DB scenarios | @team-platform | 2024-02-28 | Medium |

### **Long-term Actions** (3+ months)

| Action | Owner | Due Date | Priority |
|--------|-------|----------|----------|
| Migrate to managed database service | @team-platform | 2024-06-01 | Low |
| Implement circuit breaker pattern | @team-backend | 2024-04-15 | Medium |

---

## **Prevention Measures**

### **Technical Improvements**
1. **Monitoring Enhancement**
   - Add connection pool utilization metrics
   - Implement proactive alerting thresholds
   - Dashboard creation for database health

2. **System Resilience**
   - Connection pool configuration optimization
   - Implement graceful degradation
   - Add retry logic with exponential backoff

3. **Automation**
   - Auto-scaling for database connections
   - Automated health checks and recovery

### **Process Improvements**
1. **Documentation**
   - Update incident response runbook
   - Create database troubleshooting guide
   - Document connection pool best practices

2. **Training**
   - Database troubleshooting workshop
   - Incident response drill practice
   - Cross-team knowledge sharing

3. **Monitoring**
   - Weekly database health reviews
   - Monthly incident response practice
   - Quarterly disaster recovery testing

---

## **Lessons Learned**

### **Technical Lessons**
- Connection pools require active monitoring and alerting
- Database connection limits should be tested under load
- Graceful degradation prevents cascading failures

### **Process Lessons**
- Clear escalation procedures reduce response time
- Regular runbook updates prevent confusion during incidents
- Cross-functional collaboration improves incident resolution

### **Communication Lessons**
- Frequent updates reduce stakeholder anxiety
- Clear impact assessment helps prioritization
- Post-incident communication builds trust

---

## **Metrics & SLA Impact**

### **Incident Metrics**
- **Detection Time:** [X] minutes (Target: <5 minutes)
- **Response Time:** [X] minutes (Target: <15 minutes for P2)
- **Resolution Time:** [X] minutes (Target: <60 minutes for P2)
- **Communication Time:** [X] minutes (Target: <30 minutes)

### **SLA Impact**
- **Monthly Uptime:** [X]% (SLA: 99.9%)
- **Error Budget Consumed:** [X]% this month
- **Remaining Error Budget:** [X]%

### **Customer Impact**
- **Support Tickets:** [X] related tickets created
- **Customer Complaints:** [X] escalations received
- **Revenue Impact:** $[X] estimated impact

---

## **Appendices**

### **Appendix A: Technical Details**
```
[DETAILED_TECHNICAL_INFORMATION]
[CONFIGURATION_DETAILS]
[LOG_EXCERPTS]
```

### **Appendix B: Communication Log**
- **14:25** - Internal #incident-response notification sent
- **14:35** - Customer support team notified
- **14:40** - Status page updated
- **14:50** - Stakeholder email sent
- **15:00** - Resolution confirmation sent

### **Appendix C: References**
- Incident ticket: [LINK]
- Monitoring dashboard: [LINK]
- Code changes: [LINK]
- Related documentation: [LINK]

---

## **Sign-off**

**Reviewed and Approved:**

- **Incident Commander:** [NAME] - [DATE]
- **Engineering Manager:** [NAME] - [DATE]
- **Product Manager:** [NAME] - [DATE]
- **Operations Lead:** [NAME] - [DATE]

**Distribution:**
- Engineering Team
- Product Team
- Customer Support
- Leadership Team

---

*This postmortem follows our blameless culture principles. The focus is on system improvements, not individual accountability.*

**Next Review Date:** [DATE] (for action item follow-up)
