from pydantic import BaseModel, Field
from typing import Any, Dict, List, Optional


# ─── Sub-models ────────────────────────────────────────────────────────────────

class SubstitutionResponse(BaseModel):
    product_id: Optional[str] = None
    product_name: str
    image_url: Optional[str] = None
    price: float
    weight_gram: float
    normal_price: Optional[float] = None
    price_per_unit: Optional[float] = None
    price_per_gram: float
    savings_percent: float


class AnalyzeMetrics(BaseModel):
    wma_price: float
    support: float
    resistance: float
    sr_position: float
    price_delta_percent: float
    price_per_unit: float
    history_points: int
    history_months: int
    volatility_percent: float
    fair_upper_bound: float
    shrinkflation: Optional[bool] = None
    price_anomaly: Optional[bool] = None


class AnalyzeTierData(BaseModel):
    name: str
    scan_limit: Optional[int] = None
    scan_period: str
    remaining_scans: Optional[int] = None
    locked_features: List[str] = Field(default_factory=list)


# ─── Analyze ───────────────────────────────────────────────────────────────────

class AnalyzeData(BaseModel):
    product_id: str
    image_url: Optional[str] = None
    score: int
    decision: str                           # WorthIt | Waspada | Mahal
    product_name: str
    scanned_price: float
    normal_price: float
    category: str
    urgency: int
    weight_gram: float
    unit_label: Optional[str] = None
    explanations: List[Any]
    metrics: AnalyzeMetrics
    tier: AnalyzeTierData


class AnalyzeResponse(BaseModel):
    status: str = "success"
    data: AnalyzeData


# ─── Dashboard ─────────────────────────────────────────────────────────────────

class RecentActivityItem(BaseModel):
    product_id: Optional[str] = None
    product_name: str
    price: float
    decision: str
    color: str
    timestamp: str
    image_url: Optional[str] = None
    category: Optional[str] = None
    unit_label: Optional[str] = None


class DashboardData(BaseModel):
    monthly_budget: float
    budget_remaining: float
    money_saved: float
    recent_activities: List[RecentActivityItem]
    daily_expenses: List[float] = Field(default_factory=list)
    expense_points: List[Dict[str, Any]] = Field(default_factory=list)
    market_insight: str = ""
    market_insight_key: Optional[str] = None
    market_insight_params: Dict[str, str] = Field(default_factory=dict)


class DashboardResponse(BaseModel):
    status: str = "success"
    data: DashboardData


# ─── Tracker ───────────────────────────────────────────────────────────────────

class CategorySpend(BaseModel):
    category: str
    amount: float
    percentage: float


class TrackerItem(BaseModel):
    product_name: str
    price_paid: float
    date: str
    decision_score: Optional[int]
    action_taken: str


class TrackerData(BaseModel):
    total_spent: float
    total_items: int
    avg_per_item: float
    by_category: List[CategorySpend]
    items: List[TrackerItem]


class TrackerResponse(BaseModel):
    status: str = "success"
    data: TrackerData


# ─── Error ─────────────────────────────────────────────────────────────────────

class ErrorDetail(BaseModel):
    code: str
    message: str
    suggestion: str


class ErrorResponse(BaseModel):
    status: str = "error"
    error: ErrorDetail


# ─── Sessions ──────────────────────────────────────────────────────────────────

# ─── Products ─────────────────────────────────────────────────────────────────

class ProductImageData(BaseModel):
    product_id: str
    image_url: str
    storage_path: str
    bucket: str


class ProductImageResponse(BaseModel):
    status: str = "success"
    data: ProductImageData


class ProductData(BaseModel):
    id: str
    name: str
    brand: Optional[str] = None
    category: str
    base_weight_gram: float
    unit_label: Optional[str] = None
    image_url: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ProductListResponse(BaseModel):
    status: str = "success"
    data: List[ProductData]


class ProductResponse(BaseModel):
    status: str = "success"
    data: ProductData


class PriceHistoryItem(BaseModel):
    id: str
    product_id: str
    price: float
    weight_gram: float
    unit_label: Optional[str] = None
    recorded_at: str
    created_at: Optional[str] = None
    updated_at: Optional[str] = None


class ProductPriceHistoryResponse(BaseModel):
    status: str = "success"
    data: List[PriceHistoryItem]


class FavoriteProductData(ProductData):
    favorite_id: str
    favorited_at: str


class FavoriteListResponse(BaseModel):
    status: str = "success"
    data: List[FavoriteProductData]


class FavoriteResponse(BaseModel):
    status: str = "success"
    data: FavoriteProductData


class FavoriteDeleteData(BaseModel):
    product_id: str
    deleted: bool


class FavoriteDeleteResponse(BaseModel):
    status: str = "success"
    data: FavoriteDeleteData


class UserBudgetData(BaseModel):
    user_id: str
    monthly_budget: float


class UserBudgetResponse(BaseModel):
    status: str = "success"
    data: UserBudgetData
