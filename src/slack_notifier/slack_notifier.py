import json
import os
import urllib3
from datetime import datetime

SLACK_WEBHOOK_URL = os.environ.get('SLACK_WEBHOOK_URL')

def lambda_handler(event, context):
    if not SLACK_WEBHOOK_URL:
        print("No Slack webhook URL configured")
        return
    
    # Parse SNS message
    sns_message = json.loads(event['Records'][0]['Sns']['Message'])
    
    alarm_name = sns_message.get('AlarmName', 'Unknown Alarm')
    new_state = sns_message.get('NewStateValue', 'Unknown')
    reason = sns_message.get('NewStateReason', 'No reason provided')
    timestamp = sns_message.get('StateChangeTime', datetime.now().isoformat())
    
    # Determine color based on alarm state
    color = "danger" if new_state == "ALARM" else "good" if new_state == "OK" else "warning"
    
    # Create Slack message
    slack_message = {
        "attachments": [
            {
                "color": color,
                "title": f"🚨 CloudWatch Alarm: {alarm_name}",
                "fields": [
                    {
                        "title": "Status",
                        "value": new_state,
                        "short": True
                    },
                    {
                        "title": "Time",
                        "value": timestamp,
                        "short": True
                    },
                    {
                        "title": "Reason",
                        "value": reason,
                        "short": False
                    }
                ],
                "footer": "AWS CloudWatch",
                "ts": int(datetime.now().timestamp())
            }
        ]
    }
    
    # Send to Slack
    http = urllib3.PoolManager()
    response = http.request(
        'POST',
        SLACK_WEBHOOK_URL,
        body=json.dumps(slack_message),
        headers={'Content-Type': 'application/json'}
    )
    
    print(f"Slack notification sent: {response.status}")
    return {"statusCode": 200}