from pydantic import BaseModel, Field


class BudgetUpdateRequest(BaseModel):
    new_budget: int = Field(..., ge=0, description="Budget bulanan baru dalam Rupiah.")


class BudgetUpdateResponse(BaseModel):
    status: str = "success"
    user_id: str
    monthly_budget: int


class UsernameUpdateRequest(BaseModel):
    display_name: str = Field(..., min_length=1, max_length=50, description="Nama tampilan baru.")


class UserProfileResponse(BaseModel):
    status: str = "success"
    user_id: str
    email: str
    display_name: str
    monthly_budget: int
    subscription_tier: str = "FREE"


class SubscriptionUpgradeResponse(BaseModel):
    status: str = "success"
    user_id: str
    subscription_tier: str
