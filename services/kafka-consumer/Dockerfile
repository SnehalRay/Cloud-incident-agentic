FROM rust:1.81 AS build
RUN apt-get update && apt-get install -y cmake libssl-dev pkg-config build-essential
WORKDIR /app
COPY Cargo.toml ./
RUN mkdir src && echo "fn main() {}" > src/main.rs \
 && cargo build --release \
 && rm -rf src
COPY src ./src
RUN touch src/main.rs && cargo build --release

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/target/release/kafka-consumer .
CMD ["./kafka-consumer"]
