from faker import Faker
from random import choice
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy.sql import func

from dtypes import User, eurozone_countries
from models import UserModel


class UserHandler:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.fake = Faker()

    def get_random(self) -> UserModel:
        return self.session.query(UserModel).order_by(func.random()).first()

    def generate(self) -> User:
        country = choice(eurozone_countries)
        now = datetime.now()

        return {
            "first_name": self.fake.first_name(),
            "last_name": self.fake.last_name(),
            "date_of_birth": self.fake.date_of_birth(minimum_age=18, maximum_age=100),
            "country": country,
            "nationality": country,
            "created_at": now,
            "updated_at": now
        }

    def handle(self, user: User) -> None:
        try:
            self.session.add(user)
            self.session.commit()
        except:
            self.session.rollback()
