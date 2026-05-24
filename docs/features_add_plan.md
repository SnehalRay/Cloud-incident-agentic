This fits the project really well. Here's how I'd think about it:

The simulation scenario:

A Kafka topic (e.g. item-events) gets messages from the backend (e.g. when items are created/updated)
A lightweight consumer service processes them — you can inject failures (throw errors on a % of messages, or simulate a downstream being down)
Failed messages after N retries go to item-events.DLQ (a separate Kafka topic)
The agent has a tool: check_dlq_depth() — it calls the Kafka admin API to get the consumer lag / message count on the DLQ topic
The incident: DLQ depth spikes → agent detects it → investigates why processing is failing
