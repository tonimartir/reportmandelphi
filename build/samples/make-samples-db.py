#!/usr/bin/env python3
"""Builds samples.db, the SQLite database of the sample reports.

The data belongs to a fictional fine-food distributor, "Mare Nostrum Fine
Foods": categories, products, customers, sales representatives, orders and
order lines for 2024 and 2025. It is generated with a fixed seed, so running
the script again gives the same database byte for byte (same content, same
row order).

It also holds FISHES, the classic Borland "biolife" table of the Fishes
sample, read from repman/repsamples/biolife.xml (MIDAS XML): the pictures are
stored as JPEG, which every render driver embeds as is.

    python make-samples-db.py <output.db>

Types are chosen so that every driver of the three engines reads them the
same way: INTEGER, REAL for money and quantities, TEXT, and DATE columns
stored as ISO text ('YYYY-MM-DD'), which FireDAC, Zeos and the .NET engine
map to dates.
"""
import base64
import datetime
import html
import io
import os
import random
import re
import sqlite3
import sys

from PIL import Image

SEED = 2026

CATEGORIES = [
    (1, 'Olive Oil & Vinegar', 'Extra virgin olive oils, aged vinegars and dressings'),
    (2, 'Cheese & Dairy', 'Cured and semi-cured cheeses from small dairies'),
    (3, 'Cured Meats', 'Hams, sausages and charcuterie'),
    (4, 'Preserves', 'Canned fish, vegetables and jams'),
    (5, 'Pasta, Rice & Grains', 'Durum wheat pasta, paella rice and pulses'),
    (6, 'Coffee & Tea', 'Roasted coffee, loose tea and infusions'),
    (7, 'Sweets & Chocolate', 'Nougat, biscuits and craft chocolate'),
    (8, 'Wines & Beverages', 'Wines, ciders and soft drinks'),
]

# (category, name, unit, price)
PRODUCTS = [
    (1, 'Arbequina Extra Virgin Olive Oil', '500 ml bottle', 9.80),
    (1, 'Picual Extra Virgin Olive Oil', '1 l bottle', 14.50),
    (1, 'Hojiblanca Olive Oil Tin', '3 l tin', 32.00),
    (1, 'Sherry Vinegar Reserva', '250 ml bottle', 6.40),
    (1, 'Balsamic Vinegar of Modena', '250 ml bottle', 7.90),
    (1, 'Lemon Infused Olive Oil', '250 ml bottle', 8.20),
    (2, 'Manchego Cured Cheese', '1 kg wheel', 21.90),
    (2, 'Idiazabal Smoked Cheese', '500 g piece', 13.40),
    (2, 'Parmigiano Reggiano 24 Months', '1 kg wedge', 26.50),
    (2, 'Goat Cheese Log', '200 g log', 4.90),
    (2, 'Pecorino Romano', '500 g piece', 12.80),
    (2, 'Tetilla Cheese', '1 kg piece', 15.60),
    (3, 'Iberian Acorn-fed Ham, sliced', '100 g pack', 11.50),
    (3, 'Chorizo from Leon', '250 g piece', 4.70),
    (3, 'Salchichon Iberico', '250 g piece', 5.30),
    (3, 'Prosciutto di Parma, sliced', '100 g pack', 6.90),
    (3, 'Lomo Embuchado', '200 g piece', 9.60),
    (4, 'Bonito del Norte in Olive Oil', '250 g jar', 8.90),
    (4, 'Galician Mussels in Escabeche', '115 g can', 4.20),
    (4, 'Cantabrian Anchovies', '50 g can', 6.80),
    (4, 'Piquillo Peppers', '290 g jar', 3.60),
    (4, 'Sour Cherry Jam', '340 g jar', 4.10),
    (4, 'Quince Paste', '400 g tray', 3.90),
    (4, 'White Asparagus from Navarra', '345 g jar', 5.70),
    (5, 'Bomba Paella Rice', '1 kg bag', 4.80),
    (5, 'Spaghetti di Gragnano', '500 g bag', 2.90),
    (5, 'Orecchiette Pugliesi', '500 g bag', 3.10),
    (5, 'Pardina Lentils', '1 kg bag', 3.40),
    (5, 'Fuentesauco Chickpeas', '1 kg bag', 3.70),
    (5, 'Carnaroli Risotto Rice', '1 kg bag', 4.30),
    (6, 'Single Origin Coffee Beans', '1 kg bag', 18.90),
    (6, 'Espresso Blend, ground', '250 g bag', 5.40),
    (6, 'Green Tea Sencha', '100 g tin', 7.20),
    (6, 'Rooibos Orange', '100 g tin', 6.10),
    (6, 'Chamomile from Aragon', '50 g bag', 3.30),
    (7, 'Jijona Soft Nougat', '300 g bar', 7.50),
    (7, 'Alicante Hard Nougat', '300 g bar', 7.50),
    (7, 'Dark Chocolate 70%', '100 g bar', 3.20),
    (7, 'Almond Biscuits', '200 g box', 4.40),
    (7, 'Cantuccini with Almonds', '250 g bag', 4.90),
    (7, 'Polvorones', '400 g box', 5.20),
    (8, 'Rioja Crianza', '750 ml bottle', 12.90),
    (8, 'Albarino Rias Baixas', '750 ml bottle', 14.20),
    (8, 'Cava Brut Nature', '750 ml bottle', 11.40),
    (8, 'Asturian Natural Cider', '700 ml bottle', 3.60),
    (8, 'Chianti Classico', '750 ml bottle', 15.80),
    (8, 'Sparkling Mineral Water', '1 l bottle', 1.30),
    (8, 'Mediterranean Lemonade', '330 ml bottle', 1.90),
]

# (country, VAT %, phone prefix, cities)
COUNTRIES = [
    ('Spain', 21, 34, ['Madrid', 'Barcelona', 'Valencia', 'Sevilla', 'Bilbao', 'Zaragoza']),
    ('France', 20, 33, ['Paris', 'Lyon', 'Marseille', 'Bordeaux', 'Toulouse']),
    ('Germany', 19, 49, ['Berlin', 'Hamburg', 'Munich', 'Cologne', 'Frankfurt']),
    ('Italy', 22, 39, ['Rome', 'Milan', 'Turin', 'Florence', 'Naples']),
    ('Portugal', 23, 351, ['Lisbon', 'Porto', 'Braga', 'Coimbra']),
    ('Netherlands', 21, 31, ['Amsterdam', 'Rotterdam', 'Utrecht']),
    ('Belgium', 21, 32, ['Brussels', 'Antwerp', 'Ghent']),
    ('United Kingdom', 0, 44, ['London', 'Manchester', 'Edinburgh', 'Bristol']),
    ('Switzerland', 0, 41, ['Zurich', 'Geneva', 'Basel']),
    ('United States', 0, 1, ['New York', 'Chicago', 'San Francisco', 'Boston', 'Miami']),
    ('Mexico', 0, 52, ['Mexico City', 'Guadalajara', 'Monterrey']),
    ('Argentina', 0, 54, ['Buenos Aires', 'Cordoba', 'Rosario']),
]

NAME_FIRST = ['Blue Harbor', 'Golden Fork', 'Casa Verde', 'Old Mill', 'Sunny Coast',
              'La Despensa', 'North Star', 'Green Valley', 'Corner', 'Saint Martin',
              'Little Italy', 'El Rincon', 'Riverside', 'Bella Vista', 'Silver Spoon',
              'Market Square', 'Olive Tree', 'Le Petit', 'Hilltop', 'Seaside',
              'Royal Oak', 'Gourmet', 'Village', 'Red Door', 'Lighthouse',
              'Cedar', 'Maple Leaf', 'Atlas', 'Aurora', 'Harvest Moon']
NAME_SECOND = ['Delicatessen', 'Market', 'Bistro', 'Grocers', 'Foods', 'Trattoria',
               'Gourmet Shop', 'Wine Bar', 'Restaurant', 'Pantry', 'Cafe',
               'Fine Foods', 'Food Hall', 'Kitchen', 'Emporium']

FIRST_NAMES = ['Ana', 'Luis', 'Marie', 'Pierre', 'Hans', 'Greta', 'Marco', 'Giulia',
               'Joao', 'Ines', 'Pieter', 'Sophie', 'Emma', 'Oliver', 'Lukas', 'Lea',
               'James', 'Olivia', 'Diego', 'Valentina', 'Sofia', 'Mateo', 'Carmen',
               'Javier', 'Elena', 'Paolo', 'Chiara', 'Thomas', 'Anna', 'David',
               'Laura', 'Miguel', 'Claire', 'Noah', 'Mia', 'Hugo', 'Alba', 'Leon']
LAST_NAMES = ['Garcia', 'Martin', 'Dubois', 'Laurent', 'Muller', 'Schmidt', 'Rossi',
              'Bianchi', 'Silva', 'Costa', 'de Vries', 'Janssens', 'Smith', 'Brown',
              'Weber', 'Fischer', 'Johnson', 'Miller', 'Lopez', 'Fernandez', 'Ricci',
              'Moreau', 'Pereira', 'Bakker', 'Peeters', 'Taylor', 'Wilson', 'Romero',
              'Navarro', 'Conti', 'Keller', 'Herrera', 'Castro', 'Ortega', 'Ruiz']

STREETS = ['Main Street', 'Harbour Road', 'Market Square', 'Church Lane', 'Park Avenue',
           'Station Road', 'King Street', 'Mill Lane', 'River Walk', 'High Street',
           'Garden Row', 'Bridge Street', 'Castle Hill', 'Sea Front', 'Oak Avenue']

EMPLOYEES = [
    (1, 'Laura', 'Navarro', 'Sales Manager', '2015-03-02', 'Iberia'),
    (2, 'Daniel', 'Costa', 'Sales Representative', '2018-09-17', 'Iberia'),
    (3, 'Claire', 'Moreau', 'Sales Representative', '2017-01-09', 'Central Europe'),
    (4, 'Lukas', 'Weber', 'Sales Representative', '2019-05-06', 'Central Europe'),
    (5, 'Giulia', 'Ricci', 'Sales Representative', '2016-11-21', 'Italy'),
    (6, 'Oliver', 'Taylor', 'Key Account Manager', '2020-02-03', 'Export'),
    (7, 'Valentina', 'Herrera', 'Sales Representative', '2021-06-14', 'Export'),
]

REGION_OF_COUNTRY = {
    'Spain': 'Iberia', 'Portugal': 'Iberia',
    'France': 'Central Europe', 'Germany': 'Central Europe',
    'Netherlands': 'Central Europe', 'Belgium': 'Central Europe',
    'Switzerland': 'Central Europe',
    'Italy': 'Italy',
    'United Kingdom': 'Export', 'United States': 'Export',
    'Mexico': 'Export', 'Argentina': 'Export',
}

SCHEMA = """
CREATE TABLE CATEGORIES (
    CATEGORY_ID   INTEGER PRIMARY KEY,
    NAME          VARCHAR(40) NOT NULL,
    DESCRIPTION   VARCHAR(80)
);
CREATE TABLE PRODUCTS (
    PRODUCT_ID    INTEGER PRIMARY KEY,
    SKU           VARCHAR(12) NOT NULL,
    EAN13         VARCHAR(13) NOT NULL,
    NAME          VARCHAR(60) NOT NULL,
    CATEGORY_ID   INTEGER NOT NULL REFERENCES CATEGORIES(CATEGORY_ID),
    UNIT          VARCHAR(20) NOT NULL,
    UNIT_PRICE    REAL NOT NULL,
    UNITS_IN_STOCK INTEGER NOT NULL,
    REORDER_LEVEL INTEGER NOT NULL
);
CREATE TABLE EMPLOYEES (
    EMPLOYEE_ID   INTEGER PRIMARY KEY,
    FIRST_NAME    VARCHAR(30) NOT NULL,
    LAST_NAME     VARCHAR(30) NOT NULL,
    TITLE         VARCHAR(40) NOT NULL,
    HIRE_DATE     DATE NOT NULL,
    REGION        VARCHAR(30) NOT NULL
);
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID   INTEGER PRIMARY KEY,
    CODE          VARCHAR(8) NOT NULL,
    COMPANY_NAME  VARCHAR(60) NOT NULL,
    CONTACT_NAME  VARCHAR(60) NOT NULL,
    ADDRESS       VARCHAR(60) NOT NULL,
    POSTAL_CODE   VARCHAR(10) NOT NULL,
    CITY          VARCHAR(40) NOT NULL,
    COUNTRY       VARCHAR(40) NOT NULL,
    PHONE         VARCHAR(20) NOT NULL,
    EMAIL         VARCHAR(60) NOT NULL,
    VAT_RATE      REAL NOT NULL,
    CUSTOMER_SINCE DATE NOT NULL
);
CREATE TABLE ORDERS (
    ORDER_ID      INTEGER PRIMARY KEY,
    ORDER_NUMBER  VARCHAR(12) NOT NULL,
    CUSTOMER_ID   INTEGER NOT NULL REFERENCES CUSTOMERS(CUSTOMER_ID),
    EMPLOYEE_ID   INTEGER NOT NULL REFERENCES EMPLOYEES(EMPLOYEE_ID),
    ORDER_DATE    DATE NOT NULL,
    SHIP_DATE     DATE,
    STATUS        VARCHAR(12) NOT NULL,
    VAT_RATE      REAL NOT NULL
);
CREATE TABLE ORDER_LINES (
    ORDER_ID      INTEGER NOT NULL REFERENCES ORDERS(ORDER_ID),
    LINE_NO       INTEGER NOT NULL,
    PRODUCT_ID    INTEGER NOT NULL REFERENCES PRODUCTS(PRODUCT_ID),
    QUANTITY      INTEGER NOT NULL,
    UNIT_PRICE    REAL NOT NULL,
    DISCOUNT      REAL NOT NULL,
    PRIMARY KEY (ORDER_ID, LINE_NO)
);
CREATE TABLE FISHES (
    SPECIES_NO    INTEGER PRIMARY KEY,
    CATEGORY      VARCHAR(15) NOT NULL,
    COMMON_NAME   VARCHAR(30) NOT NULL,
    SPECIES_NAME  VARCHAR(40) NOT NULL,
    LENGTH_CM     REAL NOT NULL,
    LENGTH_IN     REAL NOT NULL,
    NOTES         TEXT,
    GRAPHIC       BLOB
);
-- NVARCHAR: FireDAC reads VARCHAR as ANSI text, which would lose these scripts
CREATE TABLE GREETINGS (
    GREETING_ID   INTEGER PRIMARY KEY,
    LANGUAGE      NVARCHAR(20) NOT NULL,
    NATIVE_NAME   NVARCHAR(30) NOT NULL,
    SCRIPT        NVARCHAR(20) NOT NULL,
    DIRECTION     NVARCHAR(3) NOT NULL,
    GREETING      NVARCHAR(80) NOT NULL,
    PARAGRAPH     NVARCHAR(400) NOT NULL
);
CREATE INDEX IX_ORDERS_CUSTOMER ON ORDERS(CUSTOMER_ID);
CREATE INDEX IX_ORDERS_DATE ON ORDERS(ORDER_DATE);
CREATE INDEX IX_PRODUCTS_CATEGORY ON PRODUCTS(CATEGORY_ID);
"""


def ean13(body12):
    """EAN-13 with its check digit from the first 12 digits."""
    total = sum(int(d) * (3 if i % 2 else 1) for i, d in enumerate(body12))
    return body12 + str((10 - total % 10) % 10)


# The same message in several scripts, for the international text sample:
# (language, native name, script, direction, greeting, paragraph)
GREETINGS = [
    ('English', 'English', 'Latin', 'LTR', 'Thank you for your order',
     'Our extra virgin olive oil is cold pressed from Arbequina olives harvested in October, '
     'and bottled within hours to keep its fruity aroma.'),
    ('Spanish', 'Español', 'Latin', 'LTR', 'Gracias por su pedido',
     'Nuestro aceite de oliva virgen extra se prensa en frío a partir de aceitunas arbequinas '
     'cosechadas en octubre, y se embotella en pocas horas para conservar su aroma afrutado.'),
    ('Greek', 'Ελληνικά', 'Greek', 'LTR', 'Ευχαριστούμε για την παραγγελία σας',
     'Το εξαιρετικό παρθένο ελαιόλαδό μας παράγεται με ψυχρή έκθλιψη από ελιές Arbequina που '
     'συλλέγονται τον Οκτώβριο, και εμφιαλώνεται μέσα σε λίγες ώρες για να διατηρήσει το '
     'φρουτώδες άρωμά του.'),
    ('Russian', 'Русский', 'Cyrillic', 'LTR', 'Спасибо за ваш заказ',
     'Наше оливковое масло extra virgin холодного отжима делается из оливок сорта арбекина, '
     'собранных в октябре, и разливается за несколько часов, чтобы сохранить фруктовый аромат.'),
    ('Arabic', 'العربية', 'Arabic', 'RTL', 'شكرًا لك على طلبك',
     'يُعصر زيت الزيتون البكر الممتاز لدينا على البارد من زيتون أربيكينا المقطوف في شهر أكتوبر، '
     'ويُعبأ في غضون ساعات قليلة للحفاظ على رائحته الفاكهية.'),
    ('Hebrew', 'עברית', 'Hebrew', 'RTL', 'תודה על ההזמנה שלך',
     'שמן הזית הכתית המעולה שלנו מופק בכבישה קרה מזיתי ארבקינה הנקטפים באוקטובר, ומבוקבק '
     'תוך שעות ספורות כדי לשמור על הארומה הפירותית שלו.'),
    ('Hindi', 'हिन्दी', 'Devanagari', 'LTR', 'आपके ऑर्डर के लिए धन्यवाद',
     'हमारा एक्स्ट्रा वर्जिन जैतून का तेल अक्टूबर में तोड़े गए अर्बेक्विना जैतूनों की ठंडी पेराई '
     'से बनता है और उसकी फल जैसी सुगंध बनाए रखने के लिए कुछ ही घंटों में बोतलबंद किया जाता है।'),
    ('Thai', 'ภาษาไทย', 'Thai', 'LTR', 'ขอบคุณสำหรับคำสั่งซื้อของคุณ',
     'น้ำมันมะกอกของเราสกัดเย็นจากมะกอกที่เก็บเกี่ยวในเดือนตุลาคม'),
    ('Japanese', '日本語', 'Japanese', 'LTR', 'ご注文ありがとうございます',
     '当店のオリーブオイルは、10月に収穫したアルベキーナ種を低温圧搾しています。'),
]

BIOLIFE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       '..', '..', 'repman', 'repsamples', 'biolife.xml')


def biolife_rows():
    """The rows of biolife.xml. A MIDAS graphic field starts with an 8 byte
    TGraphicHeader (count, type, size) before the BMP."""
    with open(BIOLIFE, encoding='utf-8') as f:
        data = f.read()
    rows = []
    for row in re.findall(r'<ROW (.*?)/>', data, re.S):
        a = {k: html.unescape(v) for k, v in re.findall(r'(\w+)="(.*?)"', row, re.S)}
        bmp = base64.b64decode(a['Graphic'])
        if bmp[:2] != b'BM':
            bmp = bmp[8:]
        jpeg = io.BytesIO()
        Image.open(io.BytesIO(bmp)).convert('RGB').save(jpeg, 'JPEG', quality=92)
        rows.append((int(float(a['Species_No'])), a['Category'], a['Common_Name'],
                     a['Species_Name'], float(a['Length__cm_']),
                     round(float(a['Length_In']), 2),
                     a.get('Notes', '').replace('\r\n', '\n'), jpeg.getvalue()))
    return rows


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    out = sys.argv[1]
    if os.path.exists(out):
        os.remove(out)
    rnd = random.Random(SEED)
    db = sqlite3.connect(out)
    db.executescript(SCHEMA)

    db.executemany('INSERT INTO CATEGORIES VALUES (?,?,?)', CATEGORIES)

    products = []
    for pid, (cat, name, unit, price) in enumerate(PRODUCTS, start=1):
        sku = 'MN-%d%03d' % (cat, pid)
        code = ean13('84%010d' % (7310000000 + pid * 37))
        reorder = rnd.choice([10, 15, 20, 25, 30])
        # A few products below their reorder level, for the stock warnings
        stock = rnd.randint(0, reorder - 1) if pid % 7 == 3 else rnd.randint(reorder, 400)
        products.append((pid, sku, code, name, cat, unit, price, stock, reorder))
    db.executemany('INSERT INTO PRODUCTS VALUES (?,?,?,?,?,?,?,?,?)', products)

    db.executemany('INSERT INTO EMPLOYEES VALUES (?,?,?,?,?,?)', EMPLOYEES)

    customers = []
    used = set()
    cid = 0
    for country, vat, prefix, cities in COUNTRIES:
        count = 7 if country in ('Spain', 'France', 'Germany', 'Italy') else rnd.randint(3, 5)
        for _ in range(count):
            while True:
                company = '%s %s' % (rnd.choice(NAME_FIRST), rnd.choice(NAME_SECOND))
                if company not in used:
                    used.add(company)
                    break
            cid += 1
            contact = '%s %s' % (rnd.choice(FIRST_NAMES), rnd.choice(LAST_NAMES))
            address = '%d %s' % (rnd.randint(1, 180), rnd.choice(STREETS))
            postal = '%05d' % rnd.randint(1000, 99999)
            phone = '+%d %03d %03d %03d' % (prefix, rnd.randint(100, 999),
                                             rnd.randint(100, 999), rnd.randint(100, 999))
            slug = ''.join(c for c in company.lower() if c.isalnum())[:18]
            email = 'orders@%s.example' % slug
            since = datetime.date(2016, 1, 1) + datetime.timedelta(days=rnd.randint(0, 2900))
            customers.append((cid, 'C%04d' % cid, company, contact, address, postal,
                              rnd.choice(cities), country, phone, email, float(vat),
                              since.isoformat()))
    db.executemany('INSERT INTO CUSTOMERS VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', customers)

    reps_by_region = {}
    for e in EMPLOYEES:
        reps_by_region.setdefault(e[5], []).append(e[0])

    # Orders: more in the last months of each year (the seasonal products)
    orders = []
    lines = []
    oid = 0
    day = datetime.date(2024, 1, 2)
    last = datetime.date(2025, 12, 30)
    while day <= last:
        if day.weekday() < 5:
            per_day = rnd.choice([0, 1, 1, 1, 2]) + (1 if day.month in (11, 12) else 0)
            for _ in range(per_day):
                oid += 1
                cust = rnd.choice(customers)
                rep = rnd.choice(reps_by_region[REGION_OF_COUNTRY[cust[7]]])
                ship = day + datetime.timedelta(days=rnd.randint(1, 6))
                status = 'Shipped' if ship <= datetime.date(2025, 12, 22) else 'Pending'
                orders.append((oid, '%d/%05d' % (day.year, oid), cust[0], rep,
                               day.isoformat(), ship.isoformat() if status == 'Shipped' else None,
                               status, cust[10]))
                chosen = rnd.sample(products, rnd.randint(1, 6))
                for n, prod in enumerate(chosen, start=1):
                    qty = rnd.choice([1, 2, 3, 4, 5, 6, 8, 10, 12, 12, 24, 24, 36, 48])
                    discount = rnd.choice([0, 0, 0, 0, 5, 10]) if qty >= 12 else 0
                    lines.append((oid, n, prod[0], qty, prod[6], float(discount)))
        day += datetime.timedelta(days=1)
    db.executemany('INSERT INTO ORDERS VALUES (?,?,?,?,?,?,?,?)', orders)
    db.executemany('INSERT INTO ORDER_LINES VALUES (?,?,?,?,?,?)', lines)

    fishes = biolife_rows()
    db.executemany('INSERT INTO FISHES VALUES (?,?,?,?,?,?,?,?)', fishes)

    db.executemany('INSERT INTO GREETINGS VALUES (?,?,?,?,?,?,?)',
                   [(n,) + g for n, g in enumerate(GREETINGS, start=1)])

    db.commit()
    db.execute('VACUUM')
    db.close()
    print('%s: %d categories, %d products, %d customers, %d employees, %d orders, '
          '%d lines, %d fishes' % (out, len(CATEGORIES), len(products), len(customers),
                                   len(EMPLOYEES), len(orders), len(lines), len(fishes)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
