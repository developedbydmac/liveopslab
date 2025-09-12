#!/bin/bash

# LiveOpsLab Service Management Script
# Stop all running services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo "🛑 Stopping LiveOpsLab services..."

# Stop FastAPI backend
if [ -f logs/fastapi.pid ]; then
    FASTAPI_PID=$(cat logs/fastapi.pid)
    if ps -p $FASTAPI_PID > /dev/null 2>&1; then
        kill $FASTAPI_PID
        print_success "Stopped FastAPI backend (PID: $FASTAPI_PID)"
    else
        print_warning "FastAPI backend process not found"
    fi
    rm -f logs/fastapi.pid
else
    print_warning "FastAPI PID file not found"
fi

# Stop dashboard
if [ -f logs/dashboard.pid ]; then
    DASHBOARD_PID=$(cat logs/dashboard.pid)
    if ps -p $DASHBOARD_PID > /dev/null 2>&1; then
        kill $DASHBOARD_PID
        print_success "Stopped dashboard (PID: $DASHBOARD_PID)"
    else
        print_warning "Dashboard process not found"
    fi
    rm -f logs/dashboard.pid
else
    print_warning "Dashboard PID file not found"
fi

# Kill any remaining uvicorn processes
UVICORN_PIDS=$(pgrep -f "uvicorn main:app" || true)
if [ ! -z "$UVICORN_PIDS" ]; then
    echo $UVICORN_PIDS | xargs kill
    print_success "Killed remaining uvicorn processes"
fi

# Kill any remaining Python HTTP server processes on port 3000
HTTP_PIDS=$(lsof -ti:3000 || true)
if [ ! -z "$HTTP_PIDS" ]; then
    echo $HTTP_PIDS | xargs kill
    print_success "Killed HTTP server on port 3000"
fi

print_success "All services stopped!"
