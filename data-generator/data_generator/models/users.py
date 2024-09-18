from datetime import datetime

from sqlalchemy import Column, String, Date, Integer, TIMESTAMP
from sqlalchemy.orm import relationship

from .common import Base


class UserModel(Base):
    __tablename__ = "users"

    id = Column(Integer(), primary_key=True, autoincrement=True)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    date_of_birth = Column(Date(), nullable=False)
    country = Column(String(2), nullable=False)
    nationality = Column(String(2), nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.now, nullable=False)
    updated_at = Column(TIMESTAMP, default=datetime.now, onupdate=datetime.now, nullable=False)

    accounts = relationship('AccountModel', back_populates='user', cascade="all, delete-orphan")
