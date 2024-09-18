from typing import TypedDict, Optional, Literal
from datetime import date, datetime

eurozone_countries = ["AT", "BE", "HR", "CY", "EE", "FI", "FR", "DE",
                      "GR", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PT", "SK", "SI", "ES"]


class Bank(TypedDict):
    id: Optional[int]
    name: str
    country: str
    currency: str
    bic_code: str
    established_date: date
    total_assets: float
    total_liabilities: float
    created_at: datetime
    updated_at: datetime


class User(TypedDict):
    id: Optional[int]
    first_name: str
    last_name: str
    date_of_birth: date
    country: str
    nationality: str
    created_at: datetime
    updated_at: datetime


class Account(TypedDict):
    id: Optional[int]
    user_id: int
    bank_id: int
    account_type: str
    currency: str
    balance: float
    status: str
    deleted_at: datetime
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class Transaction(TypedDict):
    id: Optional[int]
    from_account_id: int
    to_account_id: int
    amount: float
    currency: str
    transaction_type: str
    status: str
    timestamp: datetime
    created_at: datetime
    updated_at: datetime
