from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional


class ScanHistoryItemResponse(BaseModel):
    id: str
    product_id: Optional[str] = None
    product_name: str
    image_url: Optional[str] = None
    category: Optional[str] = None
    scanned_at: str
    score: Optional[int] = None
    decision: Optional[str] = None
    scanned_price: Optional[float] = None
    normal_price: Optional[float] = None
    analysis: Dict[str, Any]


class ScanHistoryResponse(BaseModel):
    status: str = "success"
    data: List[ScanHistoryItemResponse]


class PurchaseCreate(BaseModel):
    product_id: str
    purchased_price: int = Field(..., ge=0)
    quantity: int = Field(default=1, ge=1)


class PurchaseItemResponse(BaseModel):
    id: str
    product_id: str
    product_name: str
    image_url: Optional[str] = None
    category: Optional[str] = None
    unit_label: Optional[str] = None
    purchased_price: int
    quantity: int
    total_price: int
    purchased_at: str


class PurchaseResponse(BaseModel):
    status: str = "success"
    data: PurchaseItemResponse


class MonthlyPurchaseGroup(BaseModel):
    month: str
    month_key: str
    total_actual_spending: int
    items: List[PurchaseItemResponse]


class MonthlyPurchaseHistoryResponse(BaseModel):
    status: str = "success"
    data: List[MonthlyPurchaseGroup]
