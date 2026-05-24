FROM gcc:14 AS build
WORKDIR /src
COPY mem_pressure.c .
RUN gcc -O2 -Wall -Wextra -o mem_pressure mem_pressure.c

FROM debian:bookworm-slim
COPY --from=build /src/mem_pressure /usr/local/bin/mem_pressure
ENTRYPOINT ["/usr/local/bin/mem_pressure"]
