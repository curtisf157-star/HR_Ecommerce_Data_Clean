// ============================================================
// ecommerce_cleaning.m
// Source : ecommerce_retail_transactions_raw.csv
// Target : ecommerce_clean
// Parity : Mirrors clean.py and 03_clean_ecommerce.sql exactly
// Usage  : Power BI Desktop -> Transform Data -> Advanced Editor
//          (paste this in, replace FilePath with your own)
// ============================================================
let
    FilePath = "C:\Users\curtis\Downloads\clean-data\ecommerce_retail_transactions_raw.csv",

    // ---- 1. Load raw CSV ----
    Source   = Csv.Document(
                   File.Contents(FilePath),
                   [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
               ),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),

    Raw = Table.TransformColumnTypes(Promoted, {
        {"Order_ID",         type text},
        {"Customer_ID",      type text},
        {"Order_Date",       type text},
        {"Product_Category", type text},
        {"Product_Name",     type text},
        {"Quantity",         type text},
        {"Unit_Price_USD",   type text},
        {"Discount_Percent", type text},
        {"Payment_Method",   type text},
        {"Shipping_City",    type text},
        {"Country",          type text},
        {"Order_Status",     type text},
        {"Customer_Rating",  type text}
    }),

    // ---- 2. Dedupe (mirrors ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_Date) = 1)
    //      Sort by Order_ID, then by raw Order_Date string, then keep first per Order_ID.
    //      NOTE: this matches the SQL caveat -- dedupe is on the RAW string, not the parsed date.
    Sorted  = Table.Sort(Raw, {{"Order_ID", Order.Ascending}, {"Order_Date", Order.Ascending}}),
    Deduped = Table.Distinct(Sorted, {"Order_ID"}),

    // ---- 3. Helper functions ----
    ParseDate = (s as any) as nullable date =>
        let
            t  = if s = null then "" else Text.Trim(Text.From(s)),
            f1 = try Date.FromText(t, [Format = "yyyy-MM-dd"])                      otherwise null,
            f2 = if f1 <> null then f1 else try Date.FromText(t, [Format = "dd/MM/yyyy"])                   otherwise null,
            f3 = if f2 <> null then f2 else try Date.FromText(t, [Format = "MM/dd/yyyy"])                   otherwise null,
            f4 = if f3 <> null then f3 else try Date.FromText(t, [Format = "MM-dd-yyyy"])                   otherwise null,
            f5 = if f4 <> null then f4 else try Date.FromText(t, [Format = "dd-MM-yyyy"])                   otherwise null,
            f6 = if f5 <> null then f5 else try Date.FromText(t, [Format = "dd MMM yyyy", Culture = "en-GB"]) otherwise null,
            f7 = if f6 <> null then f6 else try Date.FromText(t, [Format = "MMM dd, yyyy", Culture = "en-US"]) otherwise null
        in
            f1 ?? f2 ?? f3 ?? f4 ?? f5 ?? f6 ?? f7,

    ParseNumber = (s as any) as nullable number =>
        let t = if s = null then "" else Text.Trim(Text.From(s))
        in  try Number.FromText(t) otherwise null,

    // ---- 4. Cleaned columns ----
    AddOrderDate = Table.AddColumn(Deduped, "Order_Date_clean", each ParseDate([Order_Date]), type nullable date),

    AddQuantity = Table.AddColumn(AddOrderDate, "Quantity_clean", each
        let q = ParseNumber([Quantity])
        in  if q <> null and q > 0 then q else null,
        Int64.Type),

    AddUnitPrice = Table.AddColumn(AddQuantity, "Unit_Price_clean", each ParseNumber([Unit_Price_USD]), type nullable number),

    AddDiscount = Table.AddColumn(AddUnitPrice, "Discount_clean", each
        let d = ParseNumber([Discount_Percent])
        in  if d = null then 0 else d,
        type number),

    AddPayment = Table.AddColumn(AddDiscount, "Payment_clean", each
        let p = Text.Lower(Text.Trim(Text.From([Payment_Method] ?? "")))
        in
            if List.Contains({"net banking", "netbanking"}, p)      then "Net Banking"
            else if List.Contains({"cash on delivery", "cod"}, p)    then "Cash on Delivery"
            else if List.Contains({"credit card", "credit_card"}, p) then "Credit Card"
            else if List.Contains({"debit card", "debit_card"}, p)   then "Debit Card"
            else if List.Contains({"upi", "u.p.i"}, p)               then "UPI"
            else if List.Contains({"paypal", "pay pal"}, p)          then "PayPal"
            else Text.Trim(Text.From([Payment_Method])),
        type text),

    AddCountry = Table.AddColumn(AddPayment, "Country_clean", each
        let c = Text.Upper(Text.Trim(Text.From([Country] ?? "")))
        in
            if List.Contains({"USA", "U.S.A", "UNITED STATES", "US"}, c) then "USA"
            else if List.Contains({"UK", "U.K.", "UNITED KINGDOM"}, c)   then "UK"
            else if List.Contains({"CANADA", "CA"}, c)                   then "Canada"
            else if List.Contains({"AUSTRALIA", "AU"}, c)                then "Australia"
            else if List.Contains({"GERMANY", "DE"}, c)                  then "Germany"
            else if List.Contains({"UAE", "U.A.E"}, c)                   then "UAE"
            else if List.Contains({"INDIA", "IN"}, c)                    then "India"
            else Text.Trim(Text.From([Country])),
        type text),

    AddStatus = Table.AddColumn(AddCountry, "Order_Status_clean", each
        let s = Text.Lower(Text.Trim(Text.From([Order_Status] ?? "")))
        in
            if s = "delivered" then "Delivered"
            else if s = "shipped"   then "Shipped"
            else if s = "pending"   then "Pending"
            else if s = "cancelled" then "Cancelled"
            else if s = "returned"  then "Returned"
            else Text.Trim(Text.From([Order_Status])),
        type text),

    AddRating = Table.AddColumn(AddStatus, "Rating_clean", each ParseNumber([Customer_Rating]), type nullable number),

    // ---- 5. Project final columns ----
    Final = Table.SelectColumns(AddRating, {
        "Order_ID", "Customer_ID", "Order_Date_clean",
        "Product_Category", "Product_Name",
        "Quantity_clean", "Unit_Price_clean", "Discount_clean",
        "Payment_clean", "Shipping_City", "Country_clean",
        "Order_Status_clean", "Rating_clean"
    }),

    Renamed = Table.RenameColumns(Final, {
        {"Order_Date_clean",    "Order_Date"},
        {"Quantity_clean",      "Quantity"},
        {"Unit_Price_clean",    "Unit_Price_USD"},
        {"Discount_clean",      "Discount_Percent"},
        {"Payment_clean",       "Payment_Method"},
        {"Country_clean",       "Country"},
        {"Order_Status_clean",  "Order_Status"},
        {"Rating_clean",        "Customer_Rating"}
    })
in
    Renamed