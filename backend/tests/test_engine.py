from engine.c_bridge import compute_wma, compute_sr_position

prices = [17000, 17200, 17500]
weights = [1, 2, 3]
current = 18000

wma = compute_wma(prices, weights)
sr_pos = compute_sr_position(current, min(prices), max(prices))

print(f"Harga Sekarang: {current}")
print(f"Harga WMA: {wma:.2f}")
print(f"S/R Position: {sr_pos:.2f}%")