# Architecture

```
Clinic (laptop / site PC)
        │  retry on network failure
        ▼
   S3 bronze bucket  (versioned)
        │  object-created event
        ▼
      SQS queue
        │
        ▼
   Lambda (validate CSV, write log object)
        │
        ├── CloudWatch alarm (errors)
        └── AWS Budget (cost cap)
```

**Load-shedding:** the clinic script retries with backoff. S3 and SQS keep the file until Lambda succeeds. Nothing requires the clinic to stay online after a successful PUT.

**Link to DE project:** the CSV shape matches `bed-occupancy-pipeline` bronze `encounters.csv`.
