# Run all unit, integration, binary, and documentation tests.
[group('test')]
test args="":
  cargo test --lib {{ args }}
  cargo test --doc {{ args }}

# Start the WebDAV container the `with-containers` tests connect to.
[group('test')]
containers_up:
  docker compose -f tests/docker-compose.yml up -d --build

# Stop and remove the WebDAV test container.
[group('test')]
containers_down:
  docker compose -f tests/docker-compose.yml down

# Generate an LCOV coverage report.
[group('test')]
coverage output="lcov.info" args="":
  cargo llvm-cov --lib --lcov --output-path {{ output }} {{ args }}
