# Library Management System – Database Project

This repository contains the implementation of a Library Management System database for the *Relational Databases* module at Heriot-Watt University.

The project includes ERD design, relational schema mapping, full DDL SQL in MariaDB/MySQL, a book return transaction procedure that satisfies ACID properties, and a written report.

---

## 📘 What This Project Includes

- **ER Diagram & Design Decisions**
  - Entities: Book, Author, Member, Location, BookCopy, Checkout, Fine, Reservation
  - M:N relationships implemented with junction tables (Book_Author, Reservation)
  - Use of composite keys, weak entities, and status tracking

- **Relational Schema**
  - Normalized to Third Normal Form (3NF)
  - Primary key and foreign key constraints
  - Referential integrity across all tables

- **SQL DDL Implementation**
  - Table creation statements
  - ENUM-based status attributes
  - Foreign key constraints with `ON DELETE CASCADE` / `SET NULL`
  - Trigger to automatically set the due date (14 days from issue)

- **Stored Procedure: `ProcessBookReturn`**
  - Calculates overdue fines (£0.5 per day)
  - Updates book return date
  - Changes book copy status back to `available`
  - Handles reservation queue (first-come-first-served)
  - Demonstrates ACID properties using transactions

- **Indexes**
  - Performance indexes on member, due_date, status, and reservation columns

---

## 🛠 Technologies

- MariaDB / MySQL
- SQL (DDL, DML, triggers, stored procedures)
- ER modelling (draw.io)
- Relational design & normalization (up to 3NF)

---

## 📄 Files in This Repository

- `LibraryManagementSystem.sql` – complete SQL script (tables, trigger, procedure, sample data)
- `DatabaseReport_LibrarySystem.docx` – full written coursework report
- `ER_Diagram.png` – ER diagram of the system (if included)
- `Screenshots/` – optional output screenshots

---

## ▶️ How to Run

1. Open MySQL or MariaDB client (e.g., MySQL Workbench).
2. Copy or import `LibraryManagementSystem.sql`.
3. Execute the script to create the database, tables, trigger, indexes, and procedure.
4. Test the return transaction with:
   ```sql
   CALL ProcessBookReturn(1);
