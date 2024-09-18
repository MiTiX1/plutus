from datetime import datetime

from sqlalchemy import Column, String, Numeric, Integer, TIMESTAMP, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import ENUM

from .common import Base, TransactionTypeEnum, TransactionStatusEnum


class TransactionModel(Base):
    __tablename__ = "transactions"

    id = Column(Integer(), primary_key=True, autoincrement=True)
    from_account_id = Column(Integer(), ForeignKey("accounts.id", ondelete="RESTRICT"), nullable=False)
    to_account_id = Column(Integer(), ForeignKey("accounts.id", ondelete="RESTRICT"), nullable=False)
    amount = Column(Numeric(18, 2), nullable=False, default=0.00)
    currency = Column(String(3), nullable=False, default='EUR')
    transaction_type = Column(ENUM(TransactionTypeEnum, name='transaction_type_enum'), nullable=False)
    status = Column(ENUM(TransactionStatusEnum, name='transaction_status_enum'), nullable=False)
    timestamp = Column(TIMESTAMP, default=datetime.now, nullable=False)
    created_at = Column(TIMESTAMP, default=datetime.now, nullable=False)
    updated_at = Column(TIMESTAMP, default=datetime.now, onupdate=datetime.now, nullable=False)

    from_account = relationship("AccountModel", foreign_keys=[from_account_id], back_populates="outgoing_transactions")
    to_account = relationship("AccountModel", foreign_keys=[to_account_id], back_populates="incoming_transactions")
