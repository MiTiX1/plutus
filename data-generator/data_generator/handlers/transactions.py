from random import uniform
from datetime import datetime

from sqlalchemy.orm import Session

from dtypes import Transaction
from models import AccountModel, TransactionModel, TransactionStatusEnum
from .accounts import AccountHandler


class TransactionHandler:
    def __init__(self, session: Session) -> None:
        self.session = session

    def generate(self) -> Transaction:
        account_model = AccountHandler(self.session)

        from_account = account_model.get_random()
        to_account = account_model.get_random()
        now = datetime.now()

        return {
            "from_account_id": from_account.id,
            "to_account_id": to_account.id,
            "amount": round(uniform(10, 1_000), 2),
            "currency": "EUR",
            "transaction_type": "transfer",
            "status": "pending",
            "timestamp": now,
            "created_at": now,
            "updated_at": now,
        }

    def handle(self, transaction: TransactionModel) -> None:
        from_account_id = transaction.from_account_id
        to_account_id = transaction.to_account_id

        from_account = self.session.query(AccountModel).filter_by(id=from_account_id).with_for_update().first()
        to_account = self.session.query(AccountModel).filter_by(id=to_account_id).with_for_update().first()

        if from_account.balance < transaction.amount:
            transaction.status = TransactionStatusEnum.failed
            try:
                self.session.add(transaction)
                self.session.commit()
            except:
                self.session.rollback()
            return

        try:
            transaction.status = TransactionStatusEnum.completed
            self.session.query(AccountModel).filter_by(id=from_account.id).update({
                "balance": float(from_account.balance) - transaction.amount
            })

            self.session.query(AccountModel).filter_by(id=to_account.id).update({
                "balance": float(to_account.balance) + transaction.amount
            })

            self.session.add(transaction)
            self.session.commit()
        except Exception as e:
            print(e)
            self.session.rollback()
