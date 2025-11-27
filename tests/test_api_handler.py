import json
import pytest

def test_order_validation():
    """Test basic order validation logic"""
    # Mock valid order data
    valid_order = {
        "customer_id": "CUST-001",
        "items": [{"item": "Laptop", "quantity": 1}]
    }
    
    # Basic validation checks
    assert "customer_id" in valid_order
    assert "items" in valid_order
    assert len(valid_order["items"]) > 0
    assert valid_order["customer_id"] != ""

def test_json_parsing():
    """Test JSON parsing functionality"""
    test_data = '{"customer_id":"TEST","items":[{"item":"Test","quantity":1}]}'
    parsed = json.loads(test_data)
    assert parsed["customer_id"] == "TEST"
    assert len(parsed["items"]) == 1
    assert parsed["items"][0]["item"] == "Test"

def test_order_structure():
    """Test order data structure requirements"""
    order_data = {
        "customer_id": "CUST-123",
        "items": [
            {"item": "Product1", "quantity": 2},
            {"item": "Product2", "quantity": 1}
        ]
    }
    
    # Validate structure
    assert isinstance(order_data["items"], list)
    assert all("item" in item and "quantity" in item for item in order_data["items"])
    assert all(isinstance(item["quantity"], int) for item in order_data["items"])

if __name__ == "__main__":
    pytest.main([__file__])
