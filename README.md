# Event-Driven Observability Platform

Serverless event-driven platform on AWS for ingesting order events, processing them asynchronously, handling retries and duplicates, and exposing operational visibility through CloudWatch dashboards, alarms, structured logs, and runbooks.

This project is intentionally focused on practical cloud engineering: reliable async processing, idempotency, DLQ handling, least-privilege IAM, and incident-oriented observability.

## Architecture

![Architecture diagram](assets/architecture.png)

- **API Gateway HTTP API** exposes the event ingestion endpoint.
- **Ingestion Lambda** validates incoming events, adds correlation metadata, emits EMF metrics, and sends accepted events to SQS.
- **SQS queue + DLQ** decouple ingestion from processing and isolate messages that exceed retry limits.
- **Processor Lambda** consumes SQS messages, applies idempotency, persists processed events, and reports partial batch failures.
- **DynamoDB** stores idempotency keys and processed order records.
- **CloudWatch + SNS** provide logs, metrics, dashboards, alarms, and alert notifications.
- **Cognito JWT authorizer** protects the ingestion API with client credentials flow.

## Key Engineering Decisions

- **SQS with DLQ:** asynchronous processing, retry isolation, and safer failure handling.
- **DynamoDB idempotency:** duplicated events are detected in the processor and skipped without duplicated downstream effects.
- **Partial batch failure handling:** failed SQS records can be retried without replaying the whole batch.
- **CloudWatch EMF metrics:** application events are emitted as structured metrics such as `EventIngested`, `EventProcessed`, `EventRejected`, `EventDuplicated`, and `EventRetried`.
- **Unresolved Events metric:** tracks accepted event messages without a terminal processing outcome:

  ```text
  UnresolvedEvents = Ingested - Processed - Rejected - Duplicated
  ```

  `EventRetried` is intentionally not subtracted because retries are intermediate attempts, not final outcomes.

- **DLQ depth as separate operational signal:** DLQ backlog is monitored with SQS metrics and not mixed into historical event-outcome math.
- **Least-privilege IAM:** ingestion and processor Lambdas use separate execution roles with permissions scoped to their responsibilities.

## Observability

The CloudWatch dashboard focuses on service health, event flow, queue health, error signals, DLQ visibility, and alarm status.

Main signals:

- API 4xx/5xx responses from API Gateway access logs.
- Lambda duration, errors, throttles, and concurrency.
- SQS queue depth, queue age, and DLQ depth.
- DynamoDB user/system errors and write throttles.
- Custom EMF metrics for event lifecycle tracking.
- Alarm status and SNS notifications.

DLQ depth represents the current backlog of failed messages waiting for investigation or replay. A future DLQ observer could emit `EventDeadLettered`, but this is not implemented yet.

## Incident Scenarios

Operational scenarios are documented with incident notes, runbooks, and screenshots:

| Scenario          | Incident                                                                   | Runbook                                                                  |
| ----------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Schema violation  | [docs/incidents/schema-violation.md](docs/incidents/schema-violation.md)   | [docs/runbooks/schema-violation.md](docs/runbooks/schema-violation.md)   |
| Ingestion failure | [docs/incidents/ingestion-failure.md](docs/incidents/ingestion-failure.md) | [docs/runbooks/ingestion-failure.md](docs/runbooks/ingestion-failure.md) |
| Duplicated event  | [docs/incidents/duplicated-event.md](docs/incidents/duplicated-event.md)   | [docs/runbooks/duplicated-event.md](docs/runbooks/duplicated-event.md)   |
| DLQ incident      | [docs/incidents/dlq-incident.md](docs/incidents/dlq-incident.md)           | [docs/runbooks/dlq-incident.md](docs/runbooks/dlq-incident.md)           |

There is also a sample postmortem for the DLQ scenario: [docs/postmortems/dlq-incident.md](docs/postmortems/dlq-incident.md).

## Repository Structure

```text
infra/envs/dev/      Terraform AWS infrastructure
services/ingestion/  API ingestion Lambda
services/processor/  SQS processor Lambda
services/shared/     Structured logging and EMF metrics
docs/                Incidents, runbooks, and postmortem
scripts/             Build and load-test helpers
assets/              Evidence screenshots
```

## Requirements

- Node.js
- Terraform
- AWS CLI configured with credentials for the target AWS account
- An email address for SNS alert subscription confirmation

## Build

Install root dependencies and package the Lambda artifacts:

```bash
npm install
npm run build
```

The build script bundles the Lambda handlers and creates deployment zips under `artifacts/`.

## Configuration

Create a local Terraform variables file from the safe example:

```bash
cp infra/envs/dev/terraform.tfvars.example infra/envs/dev/terraform.tfvars
```

Then edit `infra/envs/dev/terraform.tfvars`:

```hcl
alerts_email = "your-email@example.com"
```

The real `terraform.tfvars` file is intentionally ignored by Git.

## Deploy

```bash
cd infra/envs/dev
terraform init
terraform validate
terraform apply
```

After applying, confirm the SNS email subscription and use the API Gateway invoke URL for test requests to `POST /events`. The route is protected by the Cognito JWT authorizer, so requests must include a valid bearer token.

The Terraform output includes a CloudWatch dashboard URL:

```bash
terraform output dashboard_url
```

## Example Event

```json
{
  "eventId": "evt-001",
  "eventName": "Order Created",
  "eventType": "OrderCreated",
  "payload": {
    "order_id": "order_001",
    "customer_id": "customer_001",
    "amount": 149.9,
    "currency": "USD"
  }
}
```

## Testing Scenarios

- **Valid event:** send a valid authenticated payload to `POST /events` and confirm `EventIngested` and `EventProcessed`.
- **Schema violation:** send a payload missing `eventId` or `eventType`; see the [schema violation runbook](docs/runbooks/schema-violation.md).
- **Duplicated event:** send the same `eventId` twice; see the [duplicated event runbook](docs/runbooks/duplicated-event.md).
- **Ingestion failure:** send a payload with `forceIngestionFailure: true`; see the [ingestion failure runbook](docs/runbooks/ingestion-failure.md).
- **DLQ incident:** send or enqueue an event with `failTransient: true`; see the [DLQ incident runbook](docs/runbooks/dlq-incident.md).

## Limitations And Future Improvements

- Automated tests are not implemented yet.
- CI/CD is not implemented yet.
- A future DLQ observer could emit `EventDeadLettered` while preserving replay/investigation semantics.
- The current environment is a single dev deployment, not a multi-environment production module.
- Some operational scenarios are intentionally simulated to demonstrate observability and incident response.

## Security And Cost Notes

- IAM roles are scoped by Lambda responsibility.
- Terraform variables avoid committing personal alert endpoints.
- DynamoDB uses on-demand billing for the dev environment.
- CloudWatch dashboards, alarms, logs, and custom metrics can generate cost; clean up resources when no longer needed.

## Cleanup

Review the Terraform-managed resources before cleanup. When the environment is no longer needed, remove it through Terraform from `infra/envs/dev`.
