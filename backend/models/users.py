from pydantic import BaseModel, Field


class BudgetUpdateRequest(BaseModel):
    new_budget: int = Field(..., ge=0, description="Budget bulanan baru dalam Rupiah.")


class BudgetUpdateResponse(BaseModel):
    status: str = "success"
    user_id: str
    monthly_budget: int
