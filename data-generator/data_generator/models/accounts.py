from datetime import datetime

from sqlalchemy import Column, String, Integer, TIMESTAMP, ForeignKey, Boolean, Numeric
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import ENUM

from .common import Base, AccountTypeEnum, AccountStatusEnum


class AccountModel(Base):
    __tablename__ = "accounts"

    id = Column(Integer(), primary_key=True, autoincrement=True)
    user_id = Column(Integer(), ForeignKey('users.id', ondelete='CASCADE'), nullable=False)
    bank_id = Column(Integer(), ForeignKey('banks.id', ondelete='CASCADE'), nullable=False)
    account_type = Column(ENUM(AccountTypeEnum, name='account_type_enum'), nullable=False)
    status = Column(ENUM(AccountStatusEnum, name='account_status_enum'), nullable=False, default='active')
    currency = Column(String(3), nullable=False, default='EUR')
    balance = Column(Numeric(18, 2), nullable=False, default=0.00)
    deleted_at = Column(TIMESTAMP, nullable=True)
    is_deleted = Column(Boolean(), default=False)
    created_at = Column(TIMESTAMP, default=datetime.now, nullable=False)
    updated_at = Column(TIMESTAMP, default=datetime.now, onupdate=datetime.now, nullable=False)

    user = relationship('UserModel', back_populates='accounts')
    bank = relationship('BankModel', back_populates='accounts')

    outgoing_transactions = relationship(
        "TransactionModel", foreign_keys="[TransactionModel.from_account_id]", back_populates="from_account")
    incoming_transactions = relationship(
        "TransactionModel", foreign_keys="[TransactionModel.to_account_id]", back_populates="to_account")
