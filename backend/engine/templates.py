"""
engine/templates.py
Dynamic deterministic explanations untuk hasil analisis WorthIt.

Mode explanations ini sengaja teknis-edukatif: istilah seperti WMA,
Support/Resistance, Price Anomaly, dan Shrinkflation tetap ditampilkan,
tetapi selalu diberi konteks supaya bisa dipahami user umum.
"""


def _rupiah(value: float) -> str:
    return f"Rp{value:,.0f}".replace(",", ".")


def _pick(options: list[str], seed: int) -> str:
    if not options:
        return ""
    return options[abs(seed) % len(options)]


def build_explanations(
    *,
    scanned_price: float,
    normal_price: float,
    urgency: int,
    analysis: dict,
    is_pro: bool,
) -> list[str]:
    explanations: list[str] = []
    delta = analysis["price_delta_percent"]
    seed = int(scanned_price + normal_price + urgency + analysis["score"])
    history_months = analysis.get("history_months", 6)

    if delta <= -5:
        explanations.append(_pick([
            "WMA menunjukkan harga normal {period} bulan terakhir sekitar {normal}. Harga scan {scan} lebih rendah, jadi nilainya sedang menarik.",
            "Harga scan berada di bawah WMA {period} bulan terakhir. Artinya, harga sekarang lebih murah dari pola harga normal produk ini.",
        ], seed).format(
            period=history_months,
            normal=_rupiah(normal_price),
            scan=_rupiah(scanned_price),
        ))
    elif delta <= 5:
        explanations.append(_pick([
            "WMA menunjukkan harga normal {period} bulan terakhir sekitar {normal}. Harga scan {scan} masih dekat dengan angka itu, jadi masih tergolong wajar.",
            "Harga scan hampir sejajar dengan WMA {period} bulan terakhir. Selisihnya kecil, sehingga belum ada tanda harga terlalu mahal.",
        ], seed).format(
            period=history_months,
            normal=_rupiah(normal_price),
            scan=_rupiah(scanned_price),
        ))
    elif delta <= 15:
        explanations.append(_pick([
            "WMA menunjukkan harga normal {period} bulan terakhir sekitar {normal}. Harga scan {scan} sudah lebih tinggi, jadi pembelian perlu dipertimbangkan.",
            "Harga scan mulai menjauh dari WMA {period} bulan terakhir. Ini belum ekstrem, tapi bukan kondisi harga terbaik.",
        ], seed).format(
            period=history_months,
            normal=_rupiah(normal_price),
            scan=_rupiah(scanned_price),
        ))
    else:
        explanations.append(_pick([
            "WMA menunjukkan harga normal {period} bulan terakhir sekitar {normal}. Harga scan {scan} jauh lebih tinggi, sehingga barang ini terlihat mahal.",
            "Harga scan sudah jauh di atas WMA {period} bulan terakhir. Ini sinyal kuat untuk menunda pembelian jika barang tidak mendesak.",
        ], seed).format(
            period=history_months,
            normal=_rupiah(normal_price),
            scan=_rupiah(scanned_price),
        ))

    sr_position = analysis["sr_position"]
    support = analysis["support"]
    resistance = analysis["resistance"]
    if sr_position <= 25:
        explanations.append(
            "Support/Resistance menunjukkan harga scan dekat area Support "
            f"{_rupiah(support)} dari {history_months} bulan terakhir. "
            "Support adalah area harga rendah yang sering menjadi titik beli lebih aman."
        )
    elif sr_position >= 75:
        explanations.append(
            "Support/Resistance menunjukkan harga scan dekat area Resistance "
            f"{_rupiah(resistance)} dari {history_months} bulan terakhir. "
            "Resistance adalah area harga tinggi, jadi peluang harga terasa mahal lebih besar."
        )
    else:
        explanations.append(
            "Support/Resistance menempatkan harga scan di area tengah antara "
            f"Support {_rupiah(support)} dan Resistance {_rupiah(resistance)} "
            f"berdasarkan data {history_months} bulan terakhir."
        )

    decision_key = analysis.get("decision", "WorthIt").lower()
    urgency_texts = {
        1: {  # Urgensi Rendah (Kebutuhan Belum Mendesak / Buat Stok)
            "worthit": "Mumpung harganya lagi bagus, boleh banget dibeli buat stok walaupun kamu belum terlalu butuh sekarang.",
            "waspada": "Karena kamu belum terlalu butuh, mending ditunda dulu belinya. Harganya kurang spesial, siapa tahu nanti ada promo.",
            "mahal": "Tunda aja dulu belinya! Selain kamu belum butuh mendesak, harganya juga lagi kelewat mahal."
        },
        2: {  # Urgensi Sedang (Kebutuhan Normal / Stok Mau Habis)
            "worthit": "Pas banget! Kamu lumayan butuh barang ini dan harganya juga lagi bersahabat. Aman untuk dibeli sekarang.",
            "waspada": "Harganya agak mepet batas wajar. Tapi kalau persediaan kamu memang sudah mau habis, masih oke kok buat dibeli.",
            "mahal": "Harganya lagi lumayan mahal nih. Kalau kebutuhannya masih bisa ditunda beberapa hari, mending tunggu dulu aja."
        },
        3: {  # Urgensi Tinggi (Kebutuhan Mendesak / Harus Beli Sekarang)
            "worthit": "Kondisinya pas banget! Kamu lagi butuh mendesak dan untungnya dapat harga yang sangat sepadan.",
            "waspada": "Mengingat kamu lagi butuh banget, beli di harga segini masih wajar kok, yang penting harganya belum kelewat batas aman.",
            "mahal": "Harganya memang lagi mahal banget. Tapi karena kondisinya sangat mendesak, saran kami beli secukupnya saja dulu untuk saat ini."
        }
    }

    mapped_urgency = urgency if urgency in [1, 2, 3] else 2
    explanation_text = urgency_texts.get(mapped_urgency, {}).get(decision_key)
    if explanation_text:
        explanations.append(explanation_text)

    if is_pro:
        price_anomaly = analysis.get("price_anomaly") or {}
        shrinkflation = analysis.get("shrinkflation") or {}

        if price_anomaly.get("detected"):
            explanations.append(
                "Price Anomaly terdeteksi: harga scan melewati batas wajar "
                f"{_rupiah(analysis['fair_upper_bound'])} yang dihitung dari pola naik-turun harga {history_months} bulan terakhir."
            )
        else:
            explanations.append(
                "Price Anomaly tidak terdeteksi. Kenaikan harga masih berada dalam batas wajar berdasarkan pola naik-turun harga historis."
            )

        if shrinkflation.get("detected"):
            weight_drop = abs(shrinkflation.get("weight_delta_percent", 0))
            unit_rise = shrinkflation.get("unit_price_delta_percent", 0)
            explanations.append(
                f"Shrinkflation terdeteksi: ukuran turun sekitar {weight_drop:.1f}% "
                f"dan harga per satuan naik sekitar {unit_rise:.1f}%. "
                "Ini berarti isi berkurang, tetapi nilai belinya tidak ikut membaik."
            )
        else:
            explanations.append(
                "Shrinkflation tidak terdeteksi. Ukuran produk masih sesuai dengan varian historis dan harga per satuannya tidak menunjukkan penyusutan nilai."
            )
    else:
        explanations.append(
            "Price Anomaly dan Shrinkflation adalah analisis lanjutan Pro. Free tetap mendapat WMA dan Support/Resistance."
        )

    return explanations
