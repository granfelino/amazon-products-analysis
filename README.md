## Amazon Products Analysis
* Data source: [LINK](https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset)
* Main goal of this analysis to refresh and practice cleaning and validating a raw dataset
    using solely SQL as my tool.

* The most tedious part of this analysis was cleaning the data which you can see here:
`sql/03-data-cleaning-*.sql`

It entailed:
    - trimming whitespace
    - removing unnecesary characters
    - transforming fake NULLs into NULLs
    - flagging duplicates
    - flagging NULLs
    - flagging impossible values

* The pipeline was:
    1. Pull raw data
    2. Split into logical tables (info and ratings)
    3. For each table:
        3.1 Create a staging table
        3.2 Clean and flag staging table
        3.3 Create a clean table (with flagged rows)
        3.4 Create an analytics table without flagged rows
            and with correct column types + constraints.
    4. Analysis

-----------------
## Results

* Main categories:
    - Electronics
    - HomeImprovement
    - Toys&Games
    - Computers&Accessories
    - Car&Motorbike
    - Home&Kitchen
    - Health&PersonalCare
    - OfficeProducts
    - MusicalInstruments

* Number of subcategories: 207

| Category                  | Subcategory Count |
|---------------------------|-------------------|
| Home & Kitchen            | 72                |
| Electronics               | 61                |
| Computers & Accessories   | 57                |
| Office Products           | 14                |
| Home Improvement          | 2                 |
| Toys & Games              | 1                 |
| Health & Personal Care    | 1                 |
| Musical Instruments       | 1                 |
| Car & Motorbike           | 1                 |

* Price and discount in this dataset:

| Metric   | Average  | Minimum | Maximum  |
|----------|----------|---------|----------|
| Price    | 5694.06  | 39.00   | 139900.00|
| Discount | 0.47     | 0.0000  | 0.9400   |

* Price in different categories:

| Category                  | Count | Min Price | Max Price | Avg Price |
|---------------------------|-------|-----------|-----------|-----------|
| Electronics               | 487   | 171.00    | 139900.00 | 10447    |
| Home & Kitchen            | 448   | 79.00     | 75990.00  | 4162     |
| Computers & Accessories   | 374   | 39.00     | 59890.00  | 1858     |
| Car & Motorbike           | 1     | 4000.00   | 4000.00   | 4000     |
| Office Products           | 31    | 50.00     | 2999.00   | 397      |
| Musical Instruments       | 2     | 699.00    | 1995.00   | 1347     |
| Health & Personal Care    | 1     | 1900.00   | 1900.00   | 1900     |
| Home Improvement          | 2     | 599.00    | 999.00    | 799      |
| Toys & Games              | 1     | 150.00    | 150.00    | 150      |

* Ratings in different categories:

| Category                  | Avg Rating | Avg Rating Count |
|---------------------------|------------|------------------|
| Office Products           | 4.31       | 4828.23          |
| Toys & Games              | 4.30       | 15867.00         |
| Home Improvement          | 4.25       | 4283.00          |
| Computers & Accessories   | 4.16       | 16332.70         |
| Electronics               | 4.07       | 27295.69         |
| Home & Kitchen            | 4.04       | 6689.21          |
| Health & Personal Care    | 4.00       | 3663.00          |
| Musical Instruments       | 3.90       | 44441.00         |
| Car & Motorbike           | 3.80       | 1118.00          |

* Top 10 rated subcategories:

| Subcategory                             | Avg Rating | Avg Rating Count |
|-----------------------------------------|------------|------------------|
| Tablets                                 | 4.60       | 2886.00          |
| Memory                                  | 4.50       | 26194.00         |
| PowerLAN Adapters                       | 4.50       | 22420.00         |
| Surge Protectors                        | 4.50       | 20668.00         |
| Painting Materials                      | 4.50       | 9427.00          |
| Basic                                   | 4.50       | 8610.00          |
| Cord Management                         | 4.50       | 5985.00          |
| Film                                    | 4.50       | 4875.00          |
| Small Appliance Parts & Accessories     | 4.50       | 2280.00          |
| Coffee Presses                          | 4.50       | 1065.00          |

* Top 10 rated products where rating > 4.5 and rating count > 10000:

| Product Name                                       | Avg Rating | Avg Rating Count |
|----------------------------------------------------|------------|-----------------|
| Swiffer Instant Electric Water Heater Faucet Ta...| 4.8        | 53803           |
| Redgear MP35 Speed-Type Gaming Mousepad (Black/...| 4.6        | 33434           |
| Spigen EZ Fit Tempered Glass Screen Protector G...| 4.6        | 26603           |
| Logitech M331 Silent Plus Wireless Mouse, 2.4GH...| 4.6        | 12375           |
| Logitech G402 Hyperion Fury USB Wired Gaming Mo...| 4.6        | 10760           |
| Logitech Pebble M350 Wireless Mouse with Blueto...| 4.6        | 10652           |

