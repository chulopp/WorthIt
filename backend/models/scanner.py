from pydantic import BaseModel, Field
from typing import List, Optional


class ScanProductCandidate(BaseModel):
    id: str
    name: str
    category: Optional[str] = None
    brand: Optional[str] = None
    image_url: Optional[str] = None


class ScanData(BaseModel):
    product_name: str
    price: int
    scanned_price: int
    weight_gram: int
    category: Optional[str] = None
    db_product_id: str = ""
    candidates: List[ScanProductCandidate] = Field(default_factory=list)


class ScanSuccessResponse(BaseModel):
    status: str = "success"
    data: ScanData


class ScanErrorResponse(BaseModel):
    status: str = "error"
    message: str
