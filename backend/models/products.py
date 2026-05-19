from pydantic import BaseModel
from typing import List, Optional


class ProductSummary(BaseModel):
    id: str
    name: str
    image_url: Optional[str] = None
    category: Optional[str] = None
    brand: Optional[str] = None
    current_price: Optional[float] = None


class ProductPricePoint(BaseModel):
    month: str
    price: int


class ProductSearchResponse(BaseModel):
    status: str = "success"
    data: List[ProductSummary]


class ProductDetailData(ProductSummary):
    brand: Optional[str] = None
    base_weight_gram: float = 0
    history: List[ProductPricePoint]


class ProductDetailResponse(BaseModel):
    status: str = "success"
    data: ProductDetailData
