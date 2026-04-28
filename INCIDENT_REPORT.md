# Incident Report — Serverless Order Processing Platform
**Project:** AWS Serverless Event-Driven Order Platform
**Date:** 2024
**Author:** Cloud Engineer
**Status:** Resolved

---

## Summary

During operation of the serverless order processing system, a recurring issue was identified where a subset of orders were failing to transition from `PENDING` to `COMPLETED` status. Failed events were accumulating in the SQS queue, causing processing delays and eventually landing in the Dead Letter Queue (DLQ) without any visibility into the root cause.

---

## Situation

The order platform processes customer orders through an event-driven pipeline:

```
API Gateway → api_handler Lambda → SQS → order_worker Lambda → DynamoDB
```

After deployment, monitoring revealed that some orders were remaining in `PENDING` status indefinitely. CloudWatch alarms triggered on two conditions:
- Lambda error count exceeded threshold
- SQS message age exceeded 10 minutes — indicating messages were not being processed in time

The DLQ was receiving messages after 3 failed retry attempts, confirming the `order_worker` Lambda was failing silently on certain events.

---

## Root Cause Analysis

Investigation was carried out across three areas:

### 1. CloudWatch Logs Analysis
Queried CloudWatch Logs Insights on the `order_worker` log group:

```sql
fields @timestamp, level, message
| filter level = "ERROR"
| sort @timestamp desc
| limit 50
```

Findings:
- Errors were being swallowed inside the Lambda handler — the exception was caught but not re-raised
- Because the function returned normally after catching the error, Lambda reported success to SQS
- SQS deleted the message assuming it was processed — the order was silently lost
- No structured error detail was being logged, making diagnosis difficult

### 2. Lambda Execution Analysis
Checked Lambda execution metrics in CloudWatch:
- `Errors` metric showed spikes correlating with DLQ message arrivals
- `Duration` metric showed some invocations timing out — the default 3-second timeout was too short for DynamoDB `UpdateItem` calls under load
- Concurrency was not the issue — execution count was within limits

### 3. SQS Queue Monitoring
Checked SQS metrics:
- `ApproximateNumberOfMessagesNotVisible` was growing — messages were being received but not deleted
- `ApproximateAgeOfOldestMessage` was exceeding the 10-minute alarm threshold
- DLQ `ApproximateNumberOfMessagesVisible` was increasing — confirmed failed messages were accumulating

**Root cause identified:**
1. Silent exception handling — errors caught and swallowed, Lambda returned success, SQS deleted messages
2. Insufficient logging — no structured error detail to diagnose failures
3. Lambda timeout too short — 3 seconds insufficient under DynamoDB load
4. No visibility into DLQ — no alarm configured on DLQ depth

---

## Actions Taken

### Fix 1 — Corrected Exception Handling in order_worker

**Before (broken):**
```python
try:
    table.update_item(
        Key={"order_id": order_id},
        UpdateExpression="SET #s = :s",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": "COMPLETED"}
    )
except ClientError as e:
    logger.error(f"Failed: {e}")
    # BUG: exception swallowed — Lambda returns success, SQS deletes message
```

**After (fixed):**
```python
try:
    table.update_item(
        Key={"order_id": order_id},
        UpdateExpression="SET #s = :s",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":s": "COMPLETED"}
    )
except ClientError as e:
    logger.error(json.dumps({
        "event": "order_update_failed",
        "order_id": order_id,
        "error_code": e.response["Error"]["Code"],
        "error_message": e.response["Error"]["Message"]
    }))
    raise  # Re-raise — Lambda reports failure, SQS retries, eventually DLQ
```

**Why this matters:**
By re-raising the exception, Lambda reports the invocation as failed to SQS. SQS keeps the message visible and retries it up to `maxReceiveCount` times (3). If all retries fail, the message moves to the DLQ — preserved for investigation and reprocessing. Without the `raise`, messages were silently deleted and orders permanently lost.

---

### Fix 2 — Improved Structured Logging

Added structured JSON logging across both Lambda functions so every error includes full context:

```python
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "message": record.getMessage(),
            "function": record.funcName,
            "module": record.module
        }
        if record.exc_info:
            log_record["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_record)
```

This allows CloudWatch Logs Insights queries like:
```sql
fields @timestamp, level, message, order_id, error_code
| filter level = "ERROR"
| stats count() by error_code
| sort @timestamp desc
```

---

### Fix 3 — Increased Lambda Timeout

Updated Terraform configuration to increase the `order_worker` timeout from 3 seconds to 30 seconds:

```hcl
resource "aws_lambda_function" "order_worker" {
  function_name = "order-worker-${var.env}"
  timeout       = 30   # Increased from 3 — allows time for DynamoDB calls under load
  ...
}
```

The 3-second default was insufficient when DynamoDB experienced brief latency spikes. 30 seconds provides adequate headroom while still failing fast enough to not block the queue.

---

### Fix 4 — Added DLQ CloudWatch Alarm

Added a CloudWatch alarm on DLQ depth so any future failures are immediately visible:

```hcl
resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  alarm_name          = "order-dlq-depth-${var.env}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0   # Alert on ANY message in DLQ
  alarm_description   = "Messages in DLQ indicate failed order processing"

  dimensions = {
    QueueName = aws_sqs_queue.order_dlq.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

Any message landing in the DLQ now triggers an immediate SNS notification to email and Slack.

---

### Fix 5 — Reprocessed DLQ Messages

After deploying the fixes, existing DLQ messages were reprocessed:
1. Verified the fix was deployed and working on new messages
2. Used the SQS console to redrive DLQ messages back to the main queue
3. Monitored CloudWatch to confirm messages processed successfully
4. Verified DynamoDB orders updated to `COMPLETED` status

---

## Result

After deploying all fixes and reprocessing DLQ messages:

| Metric | Before | After |
|---|---|---|
| Orders stuck in PENDING | Growing | Zero |
| DLQ message count | Accumulating | Zero |
| Lambda error rate | Elevated | Baseline |
| SQS message age | Exceeding 10 min | Under 1 min |
| Error visibility | None | Full structured logs |

- Failed events reduced to zero within 30 minutes of deployment
- All previously failed orders were successfully reprocessed from the DLQ
- System stability confirmed over 48-hour monitoring period
- DLQ alarm now provides immediate notification of any future failures

---

## Lessons Learned

1. **Never swallow exceptions in event-driven systems** — if a Lambda processing an SQS message catches an exception and returns normally, SQS deletes the message. The failure is silent and the data is lost. Always re-raise exceptions so SQS can retry.

2. **Structured logging is not optional** — plain text logs are nearly impossible to query at scale. JSON logs with consistent fields (order_id, error_code, timestamp) make diagnosis fast.

3. **Always alarm on DLQ depth** — the DLQ is your safety net. If you don't monitor it, you won't know it's filling up until users complain.

4. **Default Lambda timeouts are too short** — the 3-second default is fine for simple functions but insufficient for functions making network calls to DynamoDB or SQS under load. Set timeouts based on measured execution time plus a safety buffer.

5. **Test failure paths, not just happy paths** — the error handling bug existed because only the success path was tested. Simulate DynamoDB failures in testing to verify retry and DLQ behaviour works correctly.

---

## Prevention Going Forward

- All Lambda functions that process SQS messages must re-raise exceptions on failure — enforced in code review
- Structured JSON logging is the standard across all Lambda functions
- DLQ alarms are provisioned by default in the Terraform monitoring module
- Lambda timeouts are set to 6x the average measured execution time
- Integration tests include failure scenarios (DynamoDB unavailable, malformed messages)
