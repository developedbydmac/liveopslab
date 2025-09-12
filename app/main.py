import time
import random
from flask import Flask, Response, request, jsonify
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import threading
import os

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'HTTP request latency')
ACTIVE_CONNECTIONS = Gauge('active_connections', 'Active connections')
CPU_USAGE = Gauge('cpu_usage_percent', 'CPU usage percentage')
MEMORY_USAGE = Gauge('memory_usage_bytes', 'Memory usage in bytes')

# Simulate some baseline metrics
def update_system_metrics():
    """Background thread to update system metrics"""
    while True:
        # Simulate CPU usage between 10-80%
        CPU_USAGE.set(random.uniform(10, 80))
        
        # Simulate memory usage between 100MB - 2GB
        MEMORY_USAGE.set(random.uniform(100_000_000, 2_000_000_000))
        
        # Simulate active connections
        ACTIVE_CONNECTIONS.set(random.randint(5, 50))
        
        time.sleep(15)

# Start metrics update thread
metrics_thread = threading.Thread(target=update_system_metrics, daemon=True)
metrics_thread.start()

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    request_latency = time.time() - request.start_time
    REQUEST_LATENCY.observe(request_latency)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    return response

@app.route('/')
def home():
    return jsonify({
        "message": "LiveOps Lab Sample Application",
        "version": "1.0.0",
        "status": "healthy"
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": time.time(),
        "uptime": time.time() - app.start_time
    })

@app.route('/api/users')
def users():
    """Simulate a user endpoint with variable latency"""
    # Simulate some processing time
    time.sleep(random.uniform(0.1, 0.5))
    
    users = [
        {"id": 1, "name": "Alice", "status": "active"},
        {"id": 2, "name": "Bob", "status": "inactive"},
        {"id": 3, "name": "Charlie", "status": "active"}
    ]
    return jsonify(users)

@app.route('/api/slow')
def slow_endpoint():
    """Intentionally slow endpoint for testing alerts"""
    time.sleep(random.uniform(2, 5))
    return jsonify({"message": "This endpoint is intentionally slow"})

@app.route('/api/error')
def error_endpoint():
    """Endpoint that randomly returns errors"""
    if random.random() < 0.3:  # 30% chance of error
        return jsonify({"error": "Simulated error"}), 500
    return jsonify({"message": "Success"})

@app.route('/api/chaos')
def chaos_endpoint():
    """Endpoint for chaos engineering - can be triggered externally"""
    chaos_mode = os.environ.get('CHAOS_MODE', 'false').lower()
    
    if chaos_mode == 'true':
        # Simulate high error rate during chaos
        if random.random() < 0.8:  # 80% error rate
            return jsonify({"error": "Chaos mode active - high error rate"}), 500
    
    if chaos_mode == 'latency':
        # Simulate high latency
        time.sleep(random.uniform(3, 8))
    
    return jsonify({
        "message": "Chaos endpoint",
        "chaos_mode": chaos_mode,
        "timestamp": time.time()
    })

@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/api/stress')
def stress():
    """CPU stress endpoint for testing"""
    duration = request.args.get('duration', 5, type=int)
    start_time = time.time()
    
    # Simple CPU stress
    while time.time() - start_time < duration:
        _ = [i**2 for i in range(1000)]
    
    return jsonify({
        "message": f"CPU stress completed for {duration} seconds",
        "duration": duration
    })

if __name__ == '__main__':
    app.start_time = time.time()
    
    # Get port from environment variable or default to 8000
    port = int(os.environ.get('PORT', 8000))
    
    print(f"Starting LiveOps Lab Sample Application on port {port}")
    print(f"Metrics available at: http://localhost:{port}/metrics")
    print(f"Health check at: http://localhost:{port}/health")
    
    app.run(host='0.0.0.0', port=port, debug=True)
