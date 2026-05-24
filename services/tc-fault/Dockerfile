FROM gcc:14 AS build
WORKDIR /src
COPY tc_fault.c .
RUN gcc -O2 -Wall -Wextra -o tc_fault tc_fault.c

FROM debian:bookworm-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      iproute2 \
      docker.io \
 && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/tc_fault /usr/local/bin/tc_fault
ENTRYPOINT ["/usr/local/bin/tc_fault"]
