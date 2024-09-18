from random import uniform
from datetime import datetime

from sqlalchemy.orm import Session
from sqlalchemy.sql import func

from dtypes import Account
from models import AccountModel
from .users import UserHandler
from .banks import BankHandler


class AccountHandler:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_random(self) -> AccountModel:
        return self.session.query(AccountModel).order_by(func.random()).first()

    def generate(self) -> Account:
        now = datetime.now()
        user_model = UserHandler(self.session)
        bank_model = BankHandler(self.session)

        return {
            "user_id": user_model.get_random().id,
            "bank_id": bank_model.get_random().id,
            "account_type": "checking",
            "status": "active",
            "currency": "EUR",
            "balance": round(uniform(100, 1_000_000), 2),
            "created_at": now,
            "updated_at": now,
            "deleted_at": None,
            "is_deleted": False,
        }

    def handle(self, account: AccountModel) -> None:
        try:
            self.session.add(account)
            self.session.commit()
        except:
            self.session.rollback()
