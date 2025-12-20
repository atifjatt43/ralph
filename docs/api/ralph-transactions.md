# Transactions

`module`

*Defined in [src/ralph/transactions.cr:17](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L17)*

Transaction support for models

This module provides transaction management capabilities including:
- Model-level transactions (`Model.transaction { ... }`)
- Nested transaction support (savepoints)
- Transaction callbacks (after_commit, after_rollback)

Example:
```
User.transaction do
  user1 = User.create(name: "Alice")
  user2 = User.create(name: "Bob")
  # Both will be saved or both will be rolled back
end
```

## Class Methods

### `.after_commit`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L56)*

Register an after_commit callback

---

### `.after_rollback`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L66)*

Register an after_rollback callback

---

### `.clear_transaction_callbacks`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L90)*

Clear all transaction callbacks

---

### `.in_transaction?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L41)*

Check if currently in a transaction

---

### `.run_after_commit_callbacks`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L76)*

Run after_commit callbacks

---

### `.run_after_rollback_callbacks`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L83)*

Run after_rollback callbacks

---

### `.transaction_committed=(value : Bool)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L51)*

Setter for transaction committed state

---

### `.transaction_committed?`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L46)*

Check if the current transaction is committed (not rolled back)

---

### `.transaction_depth`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L31)*

Get the current transaction depth

---

### `.transaction_depth=(value : Int32)`

*[View source](https://github.com/watzon/ralph/blob/main/src/ralph/transactions.cr#L36)*

Increment transaction depth

---

