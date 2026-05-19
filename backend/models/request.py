from pydantic import BaseModel, Field


class AnalyzeRequest(BaseModel):
    db_product_id: str = Field(..., description="UUID produk dari hasil OCR/database match")
    scanned_price: float = Field(..., gt=0, description="Harga yang dibaca user/OCR di rak (Rp)")
    weight_gram: float = Field(..., gt=0, description="Berat/volume produk (gram/ml)")
    urgency: int = Field(..., ge=1, le=3, description="Tingkat kebutuhan: 1=rendah, 2=sedang, 3=tinggi")

    model_config = {
        "json_schema_extra": {
            "examples": [{
                "db_product_id": "550e8400-e29b-41d4-a716-446655440000",
                "scanned_price": 3500,
                "weight_gram": 80,
                "urgency": 2
            }]
        }
    }


class FavoriteCreateRequest(BaseModel):
    product_id: str = Field(..., description="UUID produk yang ingin ditambahkan ke favorit")


class UserBudgetUpdateRequest(BaseModel):
    monthly_budget: int = Field(..., ge=0, description="Budget bulanan user dalam Rupiah")
