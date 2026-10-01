-- Report Manager examples for Lazarus: the PostgreSQL sample database that
-- sales_sqldb.rep and sales_zeos.rep print. createdb.sh loads it in the
-- database rpsample; it can be loaded again (it drops its tables first).

set client_min_messages = warning;

drop table if exists sales;
drop table if exists products;
drop table if exists customers;

create table customers (
  id integer primary key,
  name varchar(60) not null,
  city varchar(40)
);

create table products (
  id integer primary key,
  name varchar(60) not null,
  price numeric(12,2) not null
);

create table sales (
  id integer primary key,
  customer_id integer not null references customers(id),
  product_id integer not null references products(id),
  sale_date date not null,
  quantity integer not null
);

-- Text with accents and other alphabets: the client and the PDF use UTF-8
insert into customers (id, name, city) values
  (1, 'Acme Corporation', 'Springfield'),
  (2, 'Café Ñandú S.L.', 'Málaga'),
  (3, 'Globex Ltd', 'London'),
  (4, 'Müller & Söhne GmbH', 'Köln'),
  (5, 'Initech', 'Austin');

insert into products (id, name, price) values
  (1, 'Laptop', 899.00),
  (2, 'Monitor 27"', 249.50),
  (3, 'Keyboard', 39.90),
  (4, 'Laser printer', 329.00),
  (5, 'Paper A4, box', 24.95),
  (6, 'Desk chair', 189.00),
  (7, 'Mouse', 19.90);

insert into sales (id, customer_id, product_id, sale_date, quantity) values
  (1, 1, 1, '2026-09-01', 2),
  (2, 1, 2, '2026-09-01', 3),
  (3, 1, 3, '2026-09-14', 5),
  (4, 2, 4, '2026-09-03', 1),
  (5, 2, 5, '2026-09-03', 10),
  (6, 2, 7, '2026-09-22', 4),
  (7, 3, 1, '2026-09-08', 1),
  (8, 3, 6, '2026-09-08', 4),
  (9, 4, 2, '2026-09-10', 2),
  (10, 4, 3, '2026-09-10', 2),
  (11, 4, 7, '2026-09-25', 2),
  (12, 5, 1, '2026-09-29', 3),
  (13, 5, 5, '2026-09-29', 6);
