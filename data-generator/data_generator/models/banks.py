from datetime import datetime

from sqlalchemy import Column, String, Date, Integer, Numeric, TIMESTAMP
from sqlalchemy.orm import relationship

from .common import Base


class BankModel(Base):
    __tablename__ = 'banks'

    id = Column(Integer(), primary_key=True, autoincrement=True)
    name = Column(String(255), nullable=False)
    country = Column(String(2), nullable=False)
    currency = Column(String(3), nullable=False, default='EUR')
    bic_code = Column(String(11), nullable=False)
    established_date = Column(Date(), nullable=False)
    total_assets = Column(Numeric(18, 2), nullable=False)
    total_liabilities = Column(Numeric(18, 2), nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.now, nullable=False)
    updated_at = Column(TIMESTAMP, default=datetime.now, onupdate=datetime.now, nullable=False)

    accounts = relationship('AccountModel', back_populates='bank', cascade="all, delete-orphan")
