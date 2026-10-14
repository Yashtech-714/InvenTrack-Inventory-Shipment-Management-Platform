package com.wms.controller;

import com.wms.model.core.InventoryItem;
import com.wms.model.core.Order;
import com.wms.model.core.Shipment;
import com.wms.repository.InventoryRepository;
import com.wms.repository.OrderRepository;
import com.wms.repository.ShipmentRepository;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * ReportController — Manager-only reporting endpoints.
 * SOLID SRP: only reporting queries here.
 * GRASP Information Expert: delegates to repositories for data.
 *
 * Caching:
 * - inventorySummary() — cached 1 hour (use inventory.update to invalidate)
 * - orderDistribution() — cached 30 mins (use order.update to invalidate)
 * - shipmentSummary() — cached 30 mins (use shipment.update to invalidate)
 */
@RestController
@RequestMapping("/reports")
public class ReportController {

	private final InventoryRepository inventoryRepository;
	private final OrderRepository orderRepository;
	private final ShipmentRepository shipmentRepository;

	public ReportController(InventoryRepository inventoryRepository,
	                         OrderRepository orderRepository,
	                         ShipmentRepository shipmentRepository) {
		this.inventoryRepository = inventoryRepository;
		this.orderRepository = orderRepository;
		this.shipmentRepository = shipmentRepository;
	}

	/** GET /reports/inventory — inventory summary with low-stock flags. */
	@GetMapping("/inventory")
	@Cacheable(value = "inventory-report", unless = "#result == null")
	public List<Map<String, Object>> inventorySummary() {
		List<InventoryItem> items = inventoryRepository.findAll();
		List<Map<String, Object>> report = items.stream().map(item -> {
			Map<String, Object> row = new LinkedHashMap<>();
			row.put("id", item.getId());
			row.put("product", item.getProduct() != null ? item.getProduct().getName() : "N/A");
			row.put("sku", item.getProduct() != null ? item.getProduct().getSku() : "N/A");
			row.put("quantity", item.getQuantity());
			row.put("reorderLevel", item.getReorderLevel());
			row.put("lowStock", item.getQuantity() != null
					&& item.getReorderLevel() != null
					&& item.getQuantity() <= item.getReorderLevel());
			row.put("location", item.getStorageLocation() != null ? item.getStorageLocation().getCode() : "Unassigned");
			return row;
		}).collect(Collectors.toList());
		return report;
	}

	/** GET /reports/orders — order count grouped by status. */
	@GetMapping("/orders")
	@Cacheable(value = "order-report", unless = "#result == null")
	public Map<String, Object> orderDistribution() {
		List<Order> orders = orderRepository.findAll();
		Map<String, Long> byStatus = orders.stream()
				.collect(Collectors.groupingBy(
						o -> o.getStatus() != null ? o.getStatus() : "UNKNOWN",
						Collectors.counting()));

		Map<String, Object> report = new LinkedHashMap<>();
		report.put("total", orders.size());
		report.put("distribution", byStatus);
		return report;
	}

	/** GET /reports/shipments — shipment tracking summary. */
	@GetMapping("/shipments")
	@Cacheable(value = "shipment-report", unless = "#result == null")
	public List<Map<String, Object>> shipmentSummary() {
		List<Shipment> shipments = shipmentRepository.findAll();
		List<Map<String, Object>> report = shipments.stream().map(s -> {
			Map<String, Object> row = new LinkedHashMap<>();
			row.put("id", s.getId());
			row.put("shipmentNumber", s.getShipmentNumber());
			row.put("status", s.getStatus());
			row.put("shippingAddress", s.getShippingAddress());
			row.put("shippedAt", s.getShippedAt());
			row.put("estimatedDelivery", s.getEstimatedDeliveryAt());
			return row;
		}).collect(Collectors.toList());
		return report;
	}
}
