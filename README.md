# Event-Driven Order Service

[![Deploy Order Service](https://github.com/yourusername/event-driven-order-service/actions/workflows/deploy.yml/badge.svg)](https://github.com/yourusername/event-driven-order-service/actions/workflows/deploy.yml)

A production-ready, serverless event-driven order processing system built on AWS using Terraform for Infrastructure as Code.

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ API Gateway │───▶│   Lambda    │───▶│     SQS     │───▶│   Lambda    │───▶│  DynamoDB   │
│             │    │ (API Handler)│    │   Queue     │    │  (Worker)   │    │   Table     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                   │                   │
                           ▼                   ▼                   ▼
                   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
                   │  CloudWatch │    │     DLQ     │    │   X-Ray     │
                   │   Metrics   │    │   Queue     │    │   Tracing   │
                   └─────────────┘    └─────────────┘    └─────────────┘
```

## ✨ Features

### Core Functionality
- **RESTful API** for order creation via API Gateway
- **Asynchronous processing** using SQS for scalability
- **Persistent storage** with DynamoDB
- **Dead Letter Queue** for failed message handling

### Observability & Monitoring
- **Distributed tracing** with AWS X-Ray
- **Structured JSON logging** for CloudWatch
- **Custom CloudWatch metrics** (OrdersReceived, OrdersProcessed)
- **Real-time monitoring dashboard**
- **Automated alerting** via email and Slack

### Production Ready
- **Infrastructure as Code** with Terraform
- **CI/CD pipeline** with GitHub Actions
- **Multi-environment support** (dev, staging, prod)
- **Error handling and retry mechanisms**
- **Rate limiting and throttling**

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- Python 3.10+
- Slack webhook URL (optional)

### Deployment

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/event-driven-order-service.git
   cd event-driven-order-service
   ```

2. **Configure variables**
   ```bash
   cd infra
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Deploy infrastructure**
   ```bash
   terraform init
   terraform get -update  # Download modules
   terraform plan
   terraform apply
   ```

4. **Test the API**
   ```bash
   curl -X POST "$(terraform output -raw api_endpoint)/orders" \
     -H "Content-Type: application/json" \
     -d '{"customer_id":"CUST-001","items":[{"item":"Laptop","quantity":1}]}'
   ```

## 📊 Monitoring

### CloudWatch Dashboard
Access your monitoring dashboard:
```bash
terraform output dashboard_url
```

### Custom Metrics
- `OrderService.OrdersReceived` - Number of orders received
- `OrderService.OrdersProcessed` - Number of orders processed

### Alerts
- **Lambda Errors**: Triggers when >5 errors occur
- **Processing Delays**: Triggers when messages age >10 minutes
- **Notifications**: Email + Slack integration

## 🔧 Configuration

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `us-east-1` |
| `env` | Environment name | `dev` |
| `alert_email` | Email for alerts | `admin@example.com` |
| `slack_webhook_url` | Slack webhook URL | `""` |

### Terraform Variables
```hcl
# terraform.tfvars
region = "us-east-1"
env = "prod"
alert_email = "alerts@yourcompany.com"
slack_webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
```

## 🧪 Testing

### Unit Tests
```bash
cd tests
python -m pytest test_api_handler.py -v
```

### Integration Tests
```bash
# Test API endpoint
API_ENDPOINT=$(cd infra && terraform output -raw api_endpoint)
curl -X POST "$API_ENDPOINT/orders" \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"TEST","items":[{"item":"TestItem","quantity":1}]}'
```

### Load Testing
```bash
# Install artillery
npm install -g artillery

# Run load test
artillery run tests/load-test.yml
```

## 🔄 CI/CD Pipeline

The project includes a complete GitHub Actions pipeline:

1. **Test**: Runs unit tests
2. **Plan**: Terraform plan for infrastructure changes
3. **Deploy**: Applies changes to AWS (main branch only)
4. **Integration Test**: Validates deployed API

### Required Secrets
Configure these in GitHub repository settings:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `ALERT_EMAIL`
- `SLACK_WEBHOOK_URL`

## 📁 Project Structure

```
event-driven-order-service/
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── infra/
│   ├── main.tf                 # Main Terraform configuration (modular)
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── terraform.tfvars.example
├── modules/                    # Terraform modules
│   ├── lambda/
│   │   └── main.tf             # Lambda functions module
│   ├── storage/
│   │   └── main.tf             # DynamoDB and SQS module
│   ├── api-gateway/
│   │   └── main.tf             # API Gateway module
│   └── monitoring/
│       └── main.tf             # CloudWatch and SNS module
├── src/
│   ├── api_handler/
│   │   ├── app.py              # API Lambda function
│   │   └── requirements.txt
│   ├── order_worker/
│   │   ├── worker.py           # Worker Lambda function
│   │   └── requirements.txt
│   └── slack_notifier/
│       └── slack_notifier.py   # Slack notification Lambda
├── tests/
│   ├── test_api_handler.py     # Unit tests
│   └── load-test.yml           # Load testing config
├── docs/
│   └── architecture.md         # Detailed architecture docs
└── README.md
```

## 🛠️ Development

### Local Development
```bash
# Install dependencies
pip install -r requirements-dev.txt

# Run tests
pytest tests/ -v

# Format code
black src/
flake8 src/
```

### Adding New Features
1. Create feature branch
2. Implement changes with tests
3. Update documentation
4. Create pull request
5. CI/CD pipeline validates and deploys

## 📈 Scaling Considerations

- **Lambda Concurrency**: Configure reserved concurrency for predictable performance
- **DynamoDB**: Consider on-demand vs provisioned capacity based on traffic patterns
- **SQS**: Implement batch processing for high-volume scenarios
- **API Gateway**: Add caching and request/response transformations

## 🔒 Security

- **IAM Roles**: Least privilege access for all components
- **VPC**: Deploy in private subnets for enhanced security
- **Encryption**: Enable encryption at rest and in transit
- **API Security**: Add authentication (JWT, API keys, or Cognito)

## 💰 Cost Optimization

- **Lambda**: Right-size memory allocation
- **DynamoDB**: Use on-demand billing for variable workloads
- **CloudWatch**: Set log retention policies
- **Reserved Capacity**: Consider for predictable workloads

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: Create an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions

## 🗑️ Cleanup

### Destroy Infrastructure
```bash
cd infra
terraform destroy
```

### Manual Cleanup (if needed)
If Terraform state is out of sync, manually delete resources:
```bash
# List and delete Lambda functions
aws lambda list-functions --query 'Functions[].FunctionName'
aws lambda delete-function --function-name <function-name>

# List and delete DynamoDB tables
aws dynamodb list-tables
aws dynamodb delete-table --table-name <table-name>

# List and delete SQS queues
aws sqs list-queues
aws sqs delete-queue --queue-url <queue-url>

# List and delete API Gateways
aws apigatewayv2 get-apis
aws apigatewayv2 delete-api --api-id <api-id>
```

## 🏆 Acknowledgments

- AWS for providing excellent serverless services
- Terraform for Infrastructure as Code capabilities
- The open-source community for tools and inspiration

---

**Built with ❤️ using AWS Serverless Technologies**