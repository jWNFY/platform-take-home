#!/bin/bash
set -e

echo "Initializing database..."

# Wait for database to be ready
until PGPASSWORD=postgres psql -h db -U postgres -d platform -c '\q' 2>/dev/null; do
    echo "Waiting for database..."
    sleep 1
done

# Run database migrations through the application
echo "Running database migrations..."
/app/main migrate

echo "Database initialization complete!"