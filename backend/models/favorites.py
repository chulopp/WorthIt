from pydantic import BaseModel, Field
from typing import List, Optional


class FavoriteCreate(BaseModel):
    product_id: str = Field(..., description="UUID produk yang ingin ditambahkan ke favorit.")


class FavoriteItemResponse(BaseModel):
    favorite_id: str
    product_id: str
    product_name: str
    image_url: Optional[str] = None
    category: Optional[str] = None
    current_price: Optional[float] = None
    favorited_at: Optional[str] = None


class FavoriteResponse(BaseModel):
    status: str = "success"
    data: FavoriteItemResponse


class FavoriteListResponse(BaseModel):
    status: str = "success"
    data: List[FavoriteItemResponse]


class FavoriteDeleteResponse(BaseModel):
    status: str = "success"
    product_id: str
    deleted: bool = True
