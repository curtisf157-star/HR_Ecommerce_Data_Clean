// ============================================================
// hr_cleaning.m
// Source : hr_attrition_messy.csv
// Target : hr_clean
// Parity : Mirrors clean.py and 02_clean_hr.sql exactly
// Usage  : Power BI Desktop -> Transform Data -> Advanced Editor
//          (paste this in, replace FilePath with your own)
// ============================================================
let
    FilePath = "C:\Users\curtis\Downloads\clean-data\hr_attrition_messy.csv",

    // ---- 1. Load raw CSV ----
    Source   = Csv.Document(
                   File.Contents(FilePath),
                   [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]
               ),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),

    // Force every column to text so parsing is deterministic
    Raw = Table.TransformColumnTypes(Promoted, {
        {"Employee_ID",        type text},
        {"Full_Name",          type text},
        {"Age",                type text},
        {"Gender",             type text},
        {"Department",         type text},
        {"Job_Title",          type text},
        {"Education",          type text},
        {"Hire_Date",          type text},
        {"Salary",             type text},
        {"Years_At_Company",   type text},
        {"Job_Satisfaction",   type text},
        {"Performance_Rating", type text},
        {"Monthly_Hours",      type text},
        {"Attrition",          type text},
        {"Region",             type text},
        {"Payment_Method",     type text},
        {"Phone",              type text},
        {"Email",              type text}
    }),

    // ---- 2. Helper functions (local to this query) ----
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

    ParseInt = (s as any) as nullable number =>
        let t = if s = null then "" else Text.Trim(Text.From(s))
        in  try Number.FromText(t) otherwise null,

    ParseSalary = (s as any) as nullable number =>
        let
            rawLower = if s = null then "" else Text.Lower(Text.Trim(Text.From(s))),
            isJunk   = List.Contains({"", "n/a", "tbd", "confidential", "null", "na"}, rawLower),
            cleaned  = Text.Replace(Text.Replace(rawLower, "$", ""), ",", ""),
            isK      = Text.EndsWith(cleaned, "k"),
            numText  = if isK then Text.Start(cleaned, Text.Length(cleaned) - 1) else cleaned,
            parsed   = try Number.FromText(numText) otherwise null,
            result   = if isJunk then null
                       else if isK and parsed <> null then parsed * 1000
                       else parsed
        in
            result,

    // ---- 3. Cleaned columns ----
    AddGender = Table.AddColumn(Raw, "Gender_clean", each
        let g = Text.Lower(Text.Trim(Text.From([Gender] ?? "")))
        in
            if List.Contains({"m", "male"}, g)                        then "Male"
            else if List.Contains({"f", "female", "fm", "fmale"}, g)  then "Female"
            else null,
        type nullable text),

    AddDepartment = Table.AddColumn(AddGender, "Department_clean", each
        let d = Text.Upper(Text.Trim(Text.From([Department] ?? "")))
        in
            if List.Contains({"MARKETING", "MKTG"}, d)         then "Marketing"
            else if List.Contains({"IT", "I.T"}, d)            then "IT"
            else if List.Contains({"HR", "H.R"}, d)            then "HR"
            else if List.Contains({"OPERATIONS", "OPS"}, d)    then "Operations"
            else if List.Contains({"ENGINEERING", "ENGG"}, d)  then "Engineering"
            else if d = "SALES"                                then "Sales"
            else if d = "LEGAL"                                then "Legal"
            else if d = "FINANCE"                              then "Finance"
            else if d = ""                                     then null
            else Text.Trim(Text.From([Department])),
        type nullable text),

    AddRegion = Table.AddColumn(AddDepartment, "Region_clean", each
        let r = Text.Upper(Text.Trim(Text.From([Region] ?? "")))
        in
            if List.Contains({"NA", "N. AMERICA", "NORTH AMERICA", "N.A."}, r) then "North America"
            else if List.Contains({"LATAM", "LATIN AMERICA"}, r)               then "Latin America"
            else if List.Contains({"APAC", "ASIA PACIFIC"}, r)                 then "Asia Pacific"
            else if List.Contains({"ME", "MID EAST", "MIDDLE EAST"}, r)        then "Middle East"
            else if List.Contains({"EUR", "EUROPE"}, r)                        then "Europe"
            else if r = ""                                                     then null
            else Text.Trim(Text.From([Region])),
        type nullable text),

    AddHireDate    = Table.AddColumn(AddRegion,     "Hire_Date_clean",   each ParseDate([Hire_Date]),          type nullable date),
    AddSalary      = Table.AddColumn(AddHireDate,   "Salary_clean",      each ParseSalary([Salary]),           type nullable number),
    AddAge         = Table.AddColumn(AddSalary,     "Age_clean",         each ParseInt([Age]),                 Int64.Type),
    AddYears       = Table.AddColumn(AddAge,        "Years_clean",       each ParseInt([Years_At_Company]),    Int64.Type),
    AddSatisfaction= Table.AddColumn(AddYears,      "Job_Sat_clean",     each ParseInt([Job_Satisfaction]),    Int64.Type),
    AddPerf        = Table.AddColumn(AddSatisfaction,"Perf_clean",       each ParseInt([Performance_Rating]),  Int64.Type),
    AddHours       = Table.AddColumn(AddPerf,       "Hours_clean",       each ParseInt([Monthly_Hours]),       Int64.Type),

    AddAttrition = Table.AddColumn(AddHours, "Attrition_clean", each
        let a = Text.Lower(Text.Trim(Text.From([Attrition] ?? "")))
        in
            if List.Contains({"yes", "y", "left"}, a)     then "Yes"
            else if List.Contains({"no", "n", "stayed"}, a) then "No"
            else null,
        type nullable text),

    // ---- 4. Project final columns in the same order as the SQL ----
    Final = Table.SelectColumns(AddAttrition, {
        "Employee_ID", "Full_Name", "Age_clean", "Gender_clean", "Department_clean",
        "Job_Title", "Education", "Hire_Date_clean", "Salary_clean",
        "Years_clean", "Job_Sat_clean", "Perf_clean", "Hours_clean",
        "Attrition_clean", "Region_clean", "Payment_Method", "Phone", "Email"
    }),

    Renamed = Table.RenameColumns(Final, {
        {"Age_clean",         "Age"},
        {"Gender_clean",      "Gender"},
        {"Department_clean",  "Department"},
        {"Hire_Date_clean",   "Hire_Date"},
        {"Salary_clean",      "Salary"},
        {"Years_clean",       "Years_At_Company"},
        {"Job_Sat_clean",     "Job_Satisfaction"},
        {"Perf_clean",        "Performance_Rating"},
        {"Hours_clean",       "Monthly_Hours"},
        {"Attrition_clean",   "Attrition"},
        {"Region_clean",      "Region"}
    })
in
    Renamed