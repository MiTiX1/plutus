import string

from faker import Faker
from random import uniform, choice
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy.sql import func

from dtypes import Bank, eurozone_countries
from models import BankModel


class BankHandler:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.fake = Faker()

    def get_random(self) -> BankModel:
        return self.session.query(BankModel).order_by(func.random()).first()

    def generate_bic_code(self, country: str) -> str:
        bank = "".join(self.fake.random_choices(elements=string.ascii_uppercase, length=4))
        location = "".join(self.fake.random_choices(elements=string.ascii_uppercase + string.digits, length=2))
        branch = "".join(self.fake.random_choices(elements=string.ascii_uppercase +
                                                  string.digits, length=3)) if choice([True, False]) else ''

        return f"{bank}{country}{location}{branch}"

    def generate(self) -> Bank:
        now = datetime.now()
        country = choice(eurozone_countries)

        return {
            "name": self.fake.company(),
            "country": country,
            "currency": "EUR",
            "bic_code": self.generate_bic_code(country),
            "established_date": self.fake.date_between(start_date='-100y', end_date='today'),
            "total_assets": round(uniform(100_000_000, 1_000_000_000), 2),
            "total_liabilities": round(uniform(1_000_0000, 1_000_000_000), 2),
            "created_at": now,
            "updated_at": now,
        }

    def handle(self, bank: BankModel) -> None:
        try:
            self.session.add(bank)
            self.session.commit()
        except:
            self.session.rollback()
