FROM rust:1.88 AS build
WORKDIR /app
COPY Cargo.toml ./
# Build deps layer — cache before copying src
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release && rm -rf src
COPY src ./src
RUN touch src/main.rs && cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/target/release/log-pipeline .
CMD ["./log-pipeline"]
