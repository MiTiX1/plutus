from enum import Enum

from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = "postgresql+psycopg2://root:root@localhost:5432/plutus"

engine = create_engine(DATABASE_URL)
session_maker = sessionmaker(bind=engine)
session = session_maker()

Base = declarative_base()
Base.metadata.create_all(engine)


class AccountTypeEnum(Enum):
    savings = "savings"
    checking = "checking"
    credit = "credit"


class AccountStatusEnum(Enum):
    active = "active"
    closed = "closed"
    frozen = "frozen"


class TransactionTypeEnum(Enum):
    transfer = "transfer"
    deposit = "deposit"
    withdrawal = "withdrawal"


class TransactionStatusEnum(Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"


class ActionEnum(Enum):
    transfer = "transfer"
    deposit = "deposit"
    withdrawal = "withdrawal"
