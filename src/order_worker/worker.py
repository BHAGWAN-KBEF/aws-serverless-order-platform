import os
import json
import time
import boto3
import logging
from botocore.exceptions import ClientError

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

DDB_TABLE = os.environ.get("DDB_TABLE")

dynamodb = boto3.resource("dynamodb")
cloudwatch = boto3.client("cloudwatch")
table = dynamodb.Table(DDB_TABLE)

def lambda_handler(event, context):
    if XRAY_ENABLED:
        xray_recorder.begin_segment('order_worker')
    
    try:
        logger.info(f"Processing SQS records: {len(event.get('Records', []))} messages")
        
        # event contains SQS records
        for record in event.get("Records", []):
            body = json.loads(record.get("body"))
            order_id = body.get("order_id")
            if not order_id:
                logger.warning("Skipping record without order_id")
                continue

            logger.info(f"Processing order: {order_id}")
            
            # Simulate processing
            time.sleep(1)

            try:
                table.update_item(
                    Key={"order_id": order_id},
                    UpdateExpression="SET #s = :s",
                    ExpressionAttributeNames={"#s": "status"},
                    ExpressionAttributeValues={":s": "COMPLETED"}
                )
                logger.info(f"Order {order_id} processed successfully")
                
                # Publish OrdersProcessed metric
                cloudwatch.put_metric_data(
                    Namespace="OrderService",
                    MetricData=[
                        {
                            "MetricName": "OrdersProcessed",
                            "Dimensions": [
                                {"Name": "Environment", "Value": "dev"}
                            ],
                            "Unit": "Count",
                            "Value": 1
                        }
                    ]
                )
            except ClientError as e:
                logger.error(f"Failed to update order {order_id}: {e}")
                # Let Lambda/ SQS manage retries by raising
                raise
    finally:
        if XRAY_ENABLED:
            xray_recorder.end_segment()
