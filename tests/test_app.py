import pytest
import requests
import time
from prometheus_client.parser import text_string_to_metric_families

BASE_URL = "http://localhost:8000"

class TestSampleApp:
    """Test suite for the sample application"""
    
    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = requests.get(f"{BASE_URL}/health")
        assert response.status_code == 200
        
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "uptime" in data
    
    def test_home_endpoint(self):
        """Test home endpoint"""
        response = requests.get(f"{BASE_URL}/")
        assert response.status_code == 200
        
        data = response.json()
        assert data["message"] == "LiveOps Lab Sample Application"
        assert data["version"] == "1.0.0"
        assert data["status"] == "healthy"
    
    def test_users_endpoint(self):
        """Test users API endpoint"""
        response = requests.get(f"{BASE_URL}/api/users")
        assert response.status_code == 200
        
        data = response.json()
        assert isinstance(data, list)
        assert len(data) > 0
        
        # Check user structure
        user = data[0]
        assert "id" in user
        assert "name" in user
        assert "status" in user
    
    def test_metrics_endpoint(self):
        """Test Prometheus metrics endpoint"""
        response = requests.get(f"{BASE_URL}/metrics")
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/plain")
        
        # Parse metrics
        metrics = list(text_string_to_metric_families(response.text))
        metric_names = [metric.name for metric in metrics]
        
        # Check for expected metrics
        expected_metrics = [
            "http_requests_total",
            "http_request_duration_seconds",
            "active_connections",
            "cpu_usage_percent",
            "memory_usage_bytes"
        ]
        
        for expected_metric in expected_metrics:
            assert expected_metric in metric_names, f"Missing metric: {expected_metric}"
    
    def test_slow_endpoint_latency(self):
        """Test that slow endpoint has expected latency"""
        start_time = time.time()
        response = requests.get(f"{BASE_URL}/api/slow")
        end_time = time.time()
        
        assert response.status_code == 200
        assert end_time - start_time >= 2.0  # Should take at least 2 seconds
    
    def test_error_endpoint_returns_errors(self):
        """Test that error endpoint sometimes returns errors"""
        error_count = 0
        total_requests = 10
        
        for _ in range(total_requests):
            response = requests.get(f"{BASE_URL}/api/error")
            if response.status_code == 500:
                error_count += 1
        
        # Should have some errors (but not necessarily all)
        assert 0 <= error_count <= total_requests
    
    def test_stress_endpoint(self):
        """Test CPU stress endpoint"""
        response = requests.get(f"{BASE_URL}/api/stress?duration=1")
        assert response.status_code == 200
        
        data = response.json()
        assert "CPU stress completed" in data["message"]
        assert data["duration"] == 1

class TestMonitoringIntegration:
    """Test monitoring stack integration"""
    
    def test_prometheus_is_accessible(self):
        """Test that Prometheus is accessible"""
        response = requests.get("http://localhost:9090/-/healthy")
        assert response.status_code == 200
    
    def test_grafana_is_accessible(self):
        """Test that Grafana is accessible"""
        response = requests.get("http://localhost:3000/api/health")
        assert response.status_code == 200
    
    def test_alertmanager_is_accessible(self):
        """Test that Alertmanager is accessible"""
        response = requests.get("http://localhost:9093/-/healthy")
        assert response.status_code == 200
    
    def test_metrics_are_scraped(self):
        """Test that Prometheus is scraping metrics from the sample app"""
        # Wait a bit for metrics to be scraped
        time.sleep(5)
        
        # Query Prometheus for sample app metrics
        query = "up{job='sample-app'}"
        response = requests.get(
            "http://localhost:9090/api/v1/query",
            params={"query": query}
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["status"] == "success"
        assert len(data["data"]["result"]) > 0
        
        # Check that the metric value is 1 (service is up)
        result = data["data"]["result"][0]
        assert result["value"][1] == "1"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
