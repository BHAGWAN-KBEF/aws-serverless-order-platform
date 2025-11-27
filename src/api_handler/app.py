import os
import json
import uuid
import boto3
import logging

try:
    from aws_xray_sdk.core import xray_recorder, patch_all
    patch_all()
    XRAY_ENABLED = True
except ImportError:
    XRAY_ENABLED = False

class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_record = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "message": record.getMessage(),
            "function": record.funcName,
            "module": record.module
        }
        return json.dumps(log_record)

logger = logging.getLogger()
logger.setLevel(logging.INFO)
handler = logging.StreamHandler()
handler.setFormatter(JsonFormatter())
logger.addHandler(handler)

SQS_URL = os.environ.get("SQS_URL")
DDB_TABLE = os.environ.get("DDB_TABLE")

sqs = boto3.client("sqs")
dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")
table = dynamodb.Table(DDB_TABLE)

def lambda_handler(event, context):
    if XRAY_ENABLED:
        xray_recorder.begin_segment('api_handler')
    
    try:
        logger.info(f"Received order request: {event}")
        
        # Publish OrdersReceived metric
        cloudwatch.put_metric_data(
            Namespace="OrderService",
            MetricData=[
                {
                    "MetricName": "OrdersReceived",
                    "Dimensions": [
                        {"Name": "Environment", "Value": "dev"}
                    ],
                    "Unit": "Count",
                    "Value": 1
                }
            ]
        )
        
        # HTTP API Proxy v2: body is event['body']
        body = event.get("body")
        if isinstance(body, str):
            try:
                body = json.loads(body)
            except Exception:
                logger.error("Invalid JSON in request body")
                return {"statusCode": 400, "body": json.dumps({"error": "invalid json"})}

        # basic validation
        if not body or "customer_id" not in body or "items" not in body:
            logger.error("Missing required fields in request")
            return {"statusCode": 400, "body": json.dumps({"error": "missing fields: customer_id, items"})}

        order_id = str(uuid.uuid4())
        order = {
            "order_id": order_id,
            "customer_id": body["customer_id"],
            "items": body["items"],
            "status": "PENDING"
        }

        logger.info(f"Creating order: {order_id}")
        
        # write initial order to DynamoDB
        table.put_item(Item=order)
        logger.info(f"Order saved to DynamoDB: {order_id}")

        # send minimal message to SQS
        sqs.send_message(QueueUrl=SQS_URL, MessageBody=json.dumps({"order_id": order_id}))
        logger.info(f"Order message sent to SQS: {order_id}")

        return {
            "statusCode": 201,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"order_id": order_id})
        }
    finally:
        if XRAY_ENABLED:
            xray_recorder.end_segment()
