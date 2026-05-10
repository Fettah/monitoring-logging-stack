# Tempo 101: Distributed Tracing for abdel-playground

Welcome to the world of Distributed Tracing! This guide will teach you how Tempo works, how to use it in your cluster, and how to see your first traces.

## 1. What is Tempo?
Tempo is a high-volume, low-cost distributed tracing backend. Unlike Jaeger or Zipkin, it doesn't index every field of every span. Instead, it stores traces in object storage (like MinIO or S3) and relies on **trace IDs** to retrieve them.

It is designed to work perfectly with:
- **Prometheus**: To find traces from metrics (e.g., "show me traces for this 500 error spike").
- **Loki**: To find traces from logs (e.g., "this log line looks weird, let me see the whole trace").

## 2. How it's deployed here
In our cluster, Tempo is deployed in **Monolithic mode** (single binary) for simplicity. It uses our internal **MinIO** instance to store the trace data in the `tempo` bucket.

## 3. The Lifecycle of a Trace
1. **The App**: Your code uses a library (OpenTelemetry) to create "Spans" (units of work).
2. **The Exporter**: The app sends these spans to Tempo (usually via OTLP protocol).
3. **The Backend**: Tempo receives the spans, batches them, and writes them to MinIO.
4. **The UI**: You open Grafana and search for a Trace ID.

## 4. Try it out: Generating Traces
We have deployed a sample application called `tracing-demo` in the `monitoring` namespace. It is a simple service that generates random traces.

### Generate traffic
You can trigger a trace manually by hitting the demo endpoint (if exposed) or just let the generator run.
To see the traces, go to: **https://grafana.local**

### How to find a trace in Grafana:
1. Go to **Explore**.
2. Select **Tempo** as the datasource.
3. Click the **Search** tab.
4. Click **Run Query**.
5. Click on a Trace ID from the results to see the waterfall diagram!

## 5. Integration: Logs to Traces
The real power comes from integration.
- In **Loki**, if a log line has a `traceID` field, Grafana will automatically show a link to "Tempo".
- In **Tempo**, you can click "Logs for this span" to jump straight into Loki at the exact time the trace happened.

## 6. Commands to remember
```bash
# Check if tempo is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# See the tracing-demo logs
kubectl logs -n monitoring -l app=tracing-demo
```
