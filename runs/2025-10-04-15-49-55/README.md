# Load Test Results - 2025-10-04-15-49-55

**Number of Assets:** 1
**Start Time:** Sat Oct  4 15:49:55 EDT 2025
**GitHub Organization:** crenshaw-dev

---

# Load Test Results

<!-- This template will be copied to each run directory and should be filled out during/after the test -->

## Test Configuration

### Environment
- **Cluster(s):** <!-- e.g., staging-cluster-1, staging-cluster-2 -->
- **Kubernetes Version:** <!-- e.g., 1.28.0 -->
- **Node Count:** <!-- Number of nodes in cluster -->
- **Node Type/Size:** <!-- e.g., n1-standard-4, t3.large -->

### Test Parameters
- **Number of Fake Assets:** <!-- Will be filled in by setup script -->
- **Test Duration:** <!-- How long the test ran -->
- **Controller Version(s):** <!-- Version of the controllers being tested -->
- **Additional Parameters:** <!-- Any other relevant configuration -->

## Pre-Test State

### Baseline Metrics
- **CPU Usage:** <!-- Baseline CPU before test -->
- **Memory Usage:** <!-- Baseline memory before test -->
- **Active Resources:** <!-- Count of resources before test -->

### Cluster Health
<!-- Document any pre-existing issues or cluster state -->

## Test Execution

### Timeline
<!-- Document key events during the test -->

| Time | Event | Notes |
|------|-------|-------|
| | Test started | |
| | | |
| | Test completed | |

### Actions Taken
<!-- Document step-by-step what you did during the test -->

1. 
2. 
3. 

## Results

### Performance Metrics

#### Controller Metrics
- **Reconciliation Rate:** <!-- reconciliations per second/minute -->
- **Reconciliation Latency:** <!-- p50, p95, p99 latencies -->
- **Queue Depth:** <!-- work queue depth over time -->
- **Error Rate:** <!-- errors per second/minute -->

#### Resource Utilization
- **CPU Usage:**
  - Controller Pod(s): <!-- peak and average -->
  - Cluster Overall: <!-- impact on cluster -->
- **Memory Usage:**
  - Controller Pod(s): <!-- peak and average -->
  - Cluster Overall: <!-- impact on cluster -->
- **Network I/O:** <!-- if relevant -->

#### Kubernetes API Server
- **Request Rate:** <!-- requests per second -->
- **Request Latency:** <!-- p50, p95, p99 -->
- **Error Rate:** <!-- 4xx, 5xx errors -->

### Functional Results
- **Assets Created Successfully:** <!-- number/percentage -->
- **Assets Failed:** <!-- number/percentage -->
- **Reconciliation Success Rate:** <!-- percentage -->

## Observations

### Positive Findings
<!-- What worked well? -->

- 
- 

### Issues Encountered
<!-- What problems occurred? -->

| Issue | Severity | Impact | Resolution |
|-------|----------|--------|------------|
| | | | |

### Bottlenecks Identified
<!-- Where are the performance constraints? -->

- 
- 

### Controller Behavior
<!-- How did the controllers respond under load? -->

- 
- 

## Logs and Traces

### Key Log Entries
<!-- Paste relevant log excerpts -->

```
<!-- paste logs here -->
```

### Error Messages
<!-- Document any error messages encountered -->

```
<!-- paste errors here -->
```

## Analysis

### Performance Assessment
<!-- Overall assessment of performance under this load -->

### Scalability Insights
<!-- What does this test tell us about scalability? -->

### Comparison to Previous Tests
<!-- If applicable, how does this compare to earlier runs? -->

## Recommendations

### Immediate Actions
<!-- What should be done right away? -->

1. 
2. 

### Future Improvements
<!-- What could be improved for better performance? -->

1. 
2. 

### Next Tests
<!-- What should be tested next? -->

1. 
2. 

## Conclusions

<!-- Overall conclusions from this load test -->

## Attachments

<!-- Reference any additional files, screenshots, or data -->

- 
- 

---

**Test Completed:** <!-- Fill in completion timestamp -->
**Documented By:** <!-- Your name -->

