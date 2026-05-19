from pydantic import BaseModel, Field
from typing import List, Optional


class ShoppingItemResponse(BaseModel):
    id: str = Field(..., description="Shopping list item ID.")
    product_id: str
    product_name: str
    image_url: Optional[str] = None
    category: str
    current_price: float
    quantity: int
    is_bought: bool = False


class MonthlyListResponse(BaseModel):
    status: str = "success"
    list_id: str
    period_month: str
    total_budget: int
    total_estimated_price: float
    items: List[ShoppingItemResponse]


class AddItemRequest(BaseModel):
    product_id: str = Field(..., description="UUID produk yang ditambahkan ke daftar belanja.")
    quantity: int = Field(default=1, ge=1, description="Jumlah item yang ditambahkan.")
