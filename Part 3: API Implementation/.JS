/* Goal: Return all products that are below their low-stock threshold for a given company.

Algorithm:

Fetch all warehouses belonging to the company.
For each warehouse, join inventory, products, and warehouses.
Filter products:
inventory.quantity < products.threshold
inventory.product_id has recent sales (e.g., last 30 days in inventory_transactions)
Fetch supplier info (first or preferred supplier).
Calculate days_until_stockout based on average daily sales rate.
Return JSON response with alerts list and total_alerts. */


import express from "express";
import { Op } from "sequelize";
import { Company, Warehouse, Product, Inventory, Supplier, SupplierProduct, InventoryTransaction } from "../models/index.js";

const router = express.Router();

/**
 * GET /api/companies/:company_id/alerts/low-stock
 * Returns low-stock alerts for a company
 */
router.get("/companies/:company_id/alerts/low-stock", async (req, res) => {
  const { company_id } = req.params;

  try {
    // Step 1: Find warehouses belonging to the company
    const warehouses = await Warehouse.findAll({ where: { company_id } });
    const warehouseIds = warehouses.map(w => w.id);

    if (!warehouseIds.length) {
      return res.json({ alerts: [], total_alerts: 0 });
    }

    // Step 2: Find low-stock products across those warehouses
    const lowStockInventories = await Inventory.findAll({
      include: [
        {
          model: Product,
          attributes: ["id", "name", "sku", "threshold"],
        },
        {
          model: Warehouse,
          attributes: ["id", "name"],
        },
      ],
      where: {
        warehouse_id: { [Op.in]: warehouseIds },
      },
    });

    const alerts = [];

    // Step 3: For each inventory item, check threshold and recent sales
    for (const inv of lowStockInventories) {
      const product = inv.Product;
      if (!product) continue;

      if (inv.quantity >= product.threshold) continue; // Not low-stock

      // Step 4: Check recent sales (last 30 days)
      const recentSales = await InventoryTransaction.findOne({
        where: {
          inventory_id: inv.id,
          change_type: "sale",
          created_at: { [Op.gte]: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) },
        },
      });

      if (!recentSales) continue; // Skip products with no recent activity

      // Step 5: Fetch supplier info (simplified: first supplier)
      const supplierLink = await SupplierProduct.findOne({
        where: { product_id: product.id },
        include: [{ model: Supplier, attributes: ["id", "name", "contact_email"] }],
      });

      // Step 6: Estimate days_until_stockout (dummy logic)
      const avgDailySales = 1; // TODO: compute from transaction history
      const daysUntilStockout = avgDailySales
        ? Math.floor(inv.quantity / avgDailySales)
        : null;

      alerts.push({
        product_id: product.id,
        product_name: product.name,
        sku: product.sku,
        warehouse_id: inv.Warehouse.id,
        warehouse_name: inv.Warehouse.name,
        current_stock: inv.quantity,
        threshold: product.threshold,
        days_until_stockout,
        supplier: supplierLink
          ? {
              id: supplierLink.Supplier.id,
              name: supplierLink.Supplier.name,
              contact_email: supplierLink.Supplier.contact_email,
            }
          : null,
      });
    }

    return res.json({
      alerts,
      total_alerts: alerts.length,
    });
  } catch (error) {
    console.error("Low-stock alert error:", error);
    res.status(500).json({ error: "Server error generating low-stock alerts" });
  }
});

export default router;
