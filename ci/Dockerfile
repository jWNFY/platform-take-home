# Dockerfile
FROM golang:1.23.2 AS builder

WORKDIR /app

# Copy only dependency files first
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy the entire source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/server

FROM debian:bullseye-slim

# Install required packages (we only need ca-certificates now, others are for debugging)
RUN apt-get update && \
    apt-get install -y ca-certificates netcat procps postgresql-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary and required files
COPY --from=builder /app/main .
COPY tables.db .
COPY ci/scripts/init-db.sh /app/init-db.sh

RUN chmod +x /app/init-db.sh
RUN ls -l /app/main && chmod +x /app/main


EXPOSE 8080 9008

CMD ["./main"]