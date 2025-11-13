def create_product():
    data = request.json
    
    # Create new product
    product = Product(
        name=data['name'],
        sku=data['sku'],
        price=data['price'],
        warehouse_id=data['warehouse_id']
    )
    
    db.session.add(product)
    db.session.commit()
    
    # Update inventory count
    inventory = Inventory(
        product_id=product.id,
        warehouse_id=data['warehouse_id'],
        quantity=data['initial_quantity']
    )
    
    db.session.add(inventory)
    db.session.commit()
    
    return {"message": "Product created", "product_id": product.id}

#1 request.json vs request.get_json()
# Issue: request.json is not guaranteed to parse JSON correctly it may be None depending on content type.
# impact: In production, the endpoint might randomly fail with typeerror: 'NoneType' object is not subscriptable if headers or payloads aren’t perfect.
# Fix: Use data = request.get_json(force=True) or request.get_json() safely.

#2 No Input Validation
# Issue: The code assumes all keys (name, sku, price, etc.) exist in the payload.
# Impact: If clients miss a field, the server will throw KeyError or insert invalid data.
# Fix: Use validation (manual or with a schema library like Marshmallow / Pydantic).

#3 Product ↔ Warehouse Relation Logic Wrong
# Issue: The code assumes a product belongs to a single warehouse (via warehouse_id on Product), but your business rule says Products can exist in multiple warehouses
#Impact: Data model breaks normalization you will either duplicate products per warehouse or lose track of multiwarehouse inventory.
#Fix: Remove warehouse_id from Product. Instead, use a separate Inventory table linking product_id ↔ warehouse_id.

#5. No Transaction / Error Handling
#Issue: Two commits are used (product then inventory), without rollback logic.
#Impact: If inventory creation fails after product commit, you get inconsistent data (product without inventory).
#Fix: Use a single transaction (session.begin() or try/except rollback pattern).

#7. Missing Optional Field Handling
#Issue: Some fields might be optional, but code assumes all exist.
#Impact: Missing keys lead to KeyError.
#Fix: Use data.get('field', default_value) pattern.

#Corrected Version

from flask import request, jsonify
from decimal import Decimal
from sqlalchemy.exc import IntegrityError

@app.route('/api/products', methods=['POST'])
def create_product():
    data = request.get_json(force=True)

    # Validate required fields
    required_fields = ['name', 'sku', 'price', 'warehouse_id', 'initial_quantity']
    missing = [f for f in required_fields if f not in data]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    try:
        # Ensure SKU is unique
        existing = Product.query.filter_by(sku=data['sku']).first()
        if existing:
            return jsonify({"error": "SKU must be unique"}), 400

        # Convert price safely to Decimal
        price = Decimal(str(data['price']))

        # Create product (without warehouse_id since it can exist in many)
        product = Product(
            name=data['name'],
            sku=data['sku'],
            price=price
        )

        # Single transaction
        with db.session.begin():
            db.session.add(product)
            db.session.flush()  # ensures product.id is available

            # Create inventory record for given warehouse
            inventory = Inventory(
                product_id=product.id,
                warehouse_id=data['warehouse_id'],
                quantity=data.get('initial_quantity', 0)
            )
            db.session.add(inventory)

        return jsonify({
            "message": "Product created successfully",
            "product_id": product.id
        }), 201

    except IntegrityError as e:
        db.session.rollback()
        return jsonify({"error": "Database integrity error"}), 400
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500
