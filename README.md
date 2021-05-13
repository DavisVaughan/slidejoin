
<!-- README.md is generated from README.Rmd. Please edit that file -->

# slidejoin

<!-- badges: start -->

[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CRAN
status](https://www.r-pkg.org/badges/version/slidejoin)](https://CRAN.R-project.org/package=slidejoin)
[![Codecov test
coverage](https://codecov.io/gh/DavisVaughan/slidejoin/branch/master/graph/badge.svg)](https://codecov.io/gh/DavisVaughan/slidejoin?branch=master)
[![R-CMD-check](https://github.com/DavisVaughan/slidejoin/workflows/R-CMD-check/badge.svg)](https://github.com/DavisVaughan/slidejoin/actions)
<!-- badges: end -->

``` r
library(slidejoin)
```

``` r
library(data.table)
library(dplyr)
library(vctrs)
```

## Examples 1

Simple case of no `by` variables to join by. Just doing a rolling join.

``` r
sales <- data.table(
  SaleId = c("S0", "S1", "S2", "S3", "S4", "S5"),
  SaleDate = as.Date(c("2013-2-20", "2014-5-1", "2014-5-1", "2014-6-15", "2014-7-1", "2014-12-31"))
)

commercials <- data.table(
  CommercialId = c("C1", "C2", "C3", "C4", "C5"),
  CommercialDate = as.Date(c("2014-1-1", "2014-4-1", "2014-7-1", "2014-9-15", "2014-9-15"))
)

sales[, RollDate := SaleDate]
commercials[, RollDate := CommercialDate]

setkey(sales, "RollDate")
setkey(commercials, "RollDate")

commercials_tbl <- as_tibble(commercials)
sales_tbl <- as_tibble(sales)

commercials_tbl
#> # A tibble: 5 x 3
#>   CommercialId CommercialDate RollDate  
#>   <chr>        <date>         <date>    
#> 1 C1           2014-01-01     2014-01-01
#> 2 C2           2014-04-01     2014-04-01
#> 3 C3           2014-07-01     2014-07-01
#> 4 C4           2014-09-15     2014-09-15
#> 5 C5           2014-09-15     2014-09-15
sales_tbl
#> # A tibble: 6 x 3
#>   SaleId SaleDate   RollDate  
#>   <chr>  <date>     <date>    
#> 1 S0     2013-02-20 2013-02-20
#> 2 S1     2014-05-01 2014-05-01
#> 3 S2     2014-05-01 2014-05-01
#> 4 S3     2014-06-15 2014-06-15
#> 5 S4     2014-07-01 2014-07-01
#> 6 S5     2014-12-31 2014-12-31

# For a given sale, what was the last commercial that aired?
# (Sale 0 occurred before any commerical was aired)
slide_join(sales_tbl, commercials_tbl, i = "RollDate")
#> # A tibble: 6 x 5
#>   SaleId SaleDate   RollDate   CommercialId CommercialDate
#>   <chr>  <date>     <date>     <chr>        <date>        
#> 1 S0     2013-02-20 2013-02-20 <NA>         NA            
#> 2 S1     2014-05-01 2014-05-01 C2           2014-04-01    
#> 3 S2     2014-05-01 2014-05-01 C2           2014-04-01    
#> 4 S3     2014-06-15 2014-06-15 C2           2014-04-01    
#> 5 S4     2014-07-01 2014-07-01 C3           2014-07-01    
#> 6 S5     2014-12-31 2014-12-31 C5           2014-09-15

# commercials[sales, roll = Inf]

# For a given commercial, how long did it take to make the next sale?
slide_join(commercials_tbl, sales_tbl, i = "RollDate", type = "nocb")
#> # A tibble: 5 x 5
#>   CommercialId CommercialDate RollDate   SaleId SaleDate  
#>   <chr>        <date>         <date>     <chr>  <date>    
#> 1 C1           2014-01-01     2014-01-01 S1     2014-05-01
#> 2 C2           2014-04-01     2014-04-01 S1     2014-05-01
#> 3 C3           2014-07-01     2014-07-01 S4     2014-07-01
#> 4 C4           2014-09-15     2014-09-15 S5     2014-12-31
#> 5 C5           2014-09-15     2014-09-15 S5     2014-12-31

# sales[commercials, roll = -Inf]


sales_grouped <- vec_rbind(sales_tbl, sales_tbl)
sales_grouped$g <- rep(c("coffee", "tea"), each = 6)
sales_grouped <- group_by(sales_grouped, g)
sales_grouped
#> # A tibble: 12 x 4
#> # Groups:   g [2]
#>    SaleId SaleDate   RollDate   g     
#>    <chr>  <date>     <date>     <chr> 
#>  1 S0     2013-02-20 2013-02-20 coffee
#>  2 S1     2014-05-01 2014-05-01 coffee
#>  3 S2     2014-05-01 2014-05-01 coffee
#>  4 S3     2014-06-15 2014-06-15 coffee
#>  5 S4     2014-07-01 2014-07-01 coffee
#>  6 S5     2014-12-31 2014-12-31 coffee
#>  7 S0     2013-02-20 2013-02-20 tea   
#>  8 S1     2014-05-01 2014-05-01 tea   
#>  9 S2     2014-05-01 2014-05-01 tea   
#> 10 S3     2014-06-15 2014-06-15 tea   
#> 11 S4     2014-07-01 2014-07-01 tea   
#> 12 S5     2014-12-31 2014-12-31 tea

# For each group of sales, when was the last commercial that aired?
# (i.e. see if these commercials affected the sales of particular sale groups)
summarise(sales_grouped, slide_join(cur_data_all(), commercials, "RollDate"))
#> `summarise()` has grouped output by 'g'. You can override using the `.groups` argument.
#> # A tibble: 12 x 6
#> # Groups:   g [2]
#>    g      SaleId SaleDate   RollDate   CommercialId CommercialDate
#>    <chr>  <chr>  <date>     <date>     <chr>        <date>        
#>  1 coffee S0     2013-02-20 2013-02-20 <NA>         NA            
#>  2 coffee S1     2014-05-01 2014-05-01 C2           2014-04-01    
#>  3 coffee S2     2014-05-01 2014-05-01 C2           2014-04-01    
#>  4 coffee S3     2014-06-15 2014-06-15 C2           2014-04-01    
#>  5 coffee S4     2014-07-01 2014-07-01 C3           2014-07-01    
#>  6 coffee S5     2014-12-31 2014-12-31 C5           2014-09-15    
#>  7 tea    S0     2013-02-20 2013-02-20 <NA>         NA            
#>  8 tea    S1     2014-05-01 2014-05-01 C2           2014-04-01    
#>  9 tea    S2     2014-05-01 2014-05-01 C2           2014-04-01    
#> 10 tea    S3     2014-06-15 2014-06-15 C2           2014-04-01    
#> 11 tea    S4     2014-07-01 2014-07-01 C3           2014-07-01    
#> 12 tea    S5     2014-12-31 2014-12-31 C5           2014-09-15
```

## Examples 2

Now we have a join variable, `by = "name"`. For each name, we want to do
a rolling join.

Setup:

``` r
isabel_website <- data.table(name = rep('Indecisive Isabel', 5),
                             session_start_time = as.POSIXct(c('2016-01-01 11:01', '2016-01-02 8:59', '2016-01-05 18:18', '2016-01-07 19:03', '2016-01-08 19:01')))
isabel_paypal <- data.table(name = 'Indecisive Isabel', purchase_time = as.POSIXct('2016-01-08 19:10'))

sally_website <- data.table(name = 'Spendy Sally', session_start_time = as.POSIXct('2016-01-03 10:00'))
sally_paypal <- data.table(name = rep('Spendy Sally', 2), purchase_time = as.POSIXct(c('2016-01-03 10:06', '2016-01-03 10:15')))

francis_website <- data.table(name = rep('Frequent Francis', 6),
                              session_start_time = as.POSIXct(c('2016-01-02 13:09', '2016-01-03 19:22', '2016-01-08 8:44', '2016-01-08 20:22', '2016-01-10 17:36', '2016-01-15 16:56')))
francis_paypal <- data.table(name = rep('Frequent Francis', 3), purchase_time = as.POSIXct(c('2016-01-03 19:28', '2016-01-08 20:33', '2016-01-10 17:46')))

erica_website <- data.table(name = rep('Error-prone Erica', 2),
                            session_start_time = as.POSIXct(c('2016-01-04 19:12', '2016-01-04 21:05')))
erica_paypal <- data.table(name = 'Error-prone Erica', purchase_time = as.POSIXct('2016-01-03 08:02'))

vivian_website <- data.table(name = rep('Visitor Vivian', 2),
                             session_start_time = as.POSIXct(c('2016-01-01 9:10', '2016-01-09 2:15')))
vivian_paypal <- erica_paypal[0] # has 0 rows, but the same column names/classes

mom_website <- vivian_website[0] # has 0 rows, but the same column names/classes
mom_paypal <- data.table(name = 'Mom', purchase_time = as.POSIXct('2015-12-02 17:58'))

website <- rbindlist(list(isabel_website, sally_website, francis_website, erica_website, vivian_website, mom_website))
paypal <- rbindlist(list(isabel_paypal, sally_paypal, francis_paypal, erica_paypal, vivian_paypal, mom_paypal))

website[, session_id:=.GRP, by = .(name, session_start_time)]
paypal[, payment_id:=.GRP, by = .(name, purchase_time)]

website[, join_time:=session_start_time]
paypal[, join_time:=purchase_time]

setkey(website, name, join_time)
setkey(paypal, name, join_time)

website_tbl <- tibble::as_tibble(website)
paypal_tbl <- tibble::as_tibble(paypal)

website_tbl
#> # A tibble: 16 x 4
#>    name              session_start_time  session_id join_time          
#>    <chr>             <dttm>                   <int> <dttm>             
#>  1 Error-prone Erica 2016-01-04 19:12:00         13 2016-01-04 19:12:00
#>  2 Error-prone Erica 2016-01-04 21:05:00         14 2016-01-04 21:05:00
#>  3 Frequent Francis  2016-01-02 13:09:00          7 2016-01-02 13:09:00
#>  4 Frequent Francis  2016-01-03 19:22:00          8 2016-01-03 19:22:00
#>  5 Frequent Francis  2016-01-08 08:44:00          9 2016-01-08 08:44:00
#>  6 Frequent Francis  2016-01-08 20:22:00         10 2016-01-08 20:22:00
#>  7 Frequent Francis  2016-01-10 17:36:00         11 2016-01-10 17:36:00
#>  8 Frequent Francis  2016-01-15 16:56:00         12 2016-01-15 16:56:00
#>  9 Indecisive Isabel 2016-01-01 11:01:00          1 2016-01-01 11:01:00
#> 10 Indecisive Isabel 2016-01-02 08:59:00          2 2016-01-02 08:59:00
#> 11 Indecisive Isabel 2016-01-05 18:18:00          3 2016-01-05 18:18:00
#> 12 Indecisive Isabel 2016-01-07 19:03:00          4 2016-01-07 19:03:00
#> 13 Indecisive Isabel 2016-01-08 19:01:00          5 2016-01-08 19:01:00
#> 14 Spendy Sally      2016-01-03 10:00:00          6 2016-01-03 10:00:00
#> 15 Visitor Vivian    2016-01-01 09:10:00         15 2016-01-01 09:10:00
#> 16 Visitor Vivian    2016-01-09 02:15:00         16 2016-01-09 02:15:00
paypal_tbl
#> # A tibble: 8 x 4
#>   name              purchase_time       payment_id join_time          
#>   <chr>             <dttm>                   <int> <dttm>             
#> 1 Error-prone Erica 2016-01-03 08:02:00          7 2016-01-03 08:02:00
#> 2 Frequent Francis  2016-01-03 19:28:00          4 2016-01-03 19:28:00
#> 3 Frequent Francis  2016-01-08 20:33:00          5 2016-01-08 20:33:00
#> 4 Frequent Francis  2016-01-10 17:46:00          6 2016-01-10 17:46:00
#> 5 Indecisive Isabel 2016-01-08 19:10:00          1 2016-01-08 19:10:00
#> 6 Mom               2015-12-02 17:58:00          8 2015-12-02 17:58:00
#> 7 Spendy Sally      2016-01-03 10:06:00          2 2016-01-03 10:06:00
#> 8 Spendy Sally      2016-01-03 10:15:00          3 2016-01-03 10:15:00
```

Examples:

``` r
# For each purchase, find the last time they visited the website
# (Mom's card was used for the purchase, but she never visited)
slide_left_join(paypal_tbl, website_tbl, "join_time", "name")
#> # A tibble: 8 x 6
#> # Groups:   name [5]
#>   name    purchase_time       payment_id join_time           session_start_time 
#>   <chr>   <dttm>                   <int> <dttm>              <dttm>             
#> 1 Error-… 2016-01-03 08:02:00          7 2016-01-03 08:02:00 NA                 
#> 2 Freque… 2016-01-03 19:28:00          4 2016-01-03 19:28:00 2016-01-03 19:22:00
#> 3 Freque… 2016-01-08 20:33:00          5 2016-01-08 20:33:00 2016-01-08 20:22:00
#> 4 Freque… 2016-01-10 17:46:00          6 2016-01-10 17:46:00 2016-01-10 17:36:00
#> 5 Indeci… 2016-01-08 19:10:00          1 2016-01-08 19:10:00 2016-01-08 19:01:00
#> 6 Mom     2015-12-02 17:58:00          8 2015-12-02 17:58:00 NA                 
#> 7 Spendy… 2016-01-03 10:06:00          2 2016-01-03 10:06:00 2016-01-03 10:00:00
#> 8 Spendy… 2016-01-03 10:15:00          3 2016-01-03 10:15:00 2016-01-03 10:00:00
#> # … with 1 more variable: session_id <int>

# website[paypal, roll = TRUE]

# For each purchase that had a website session, find the last time they visited
# (So Mom gets excluded)
slide_inner_join(paypal_tbl, website_tbl, "join_time", "name")
#> # A tibble: 7 x 6
#> # Groups:   name [4]
#>   name    purchase_time       payment_id join_time           session_start_time 
#>   <chr>   <dttm>                   <int> <dttm>              <dttm>             
#> 1 Error-… 2016-01-03 08:02:00          7 2016-01-03 08:02:00 NA                 
#> 2 Freque… 2016-01-03 19:28:00          4 2016-01-03 19:28:00 2016-01-03 19:22:00
#> 3 Freque… 2016-01-08 20:33:00          5 2016-01-08 20:33:00 2016-01-08 20:22:00
#> 4 Freque… 2016-01-10 17:46:00          6 2016-01-10 17:46:00 2016-01-10 17:36:00
#> 5 Indeci… 2016-01-08 19:10:00          1 2016-01-08 19:10:00 2016-01-08 19:01:00
#> 6 Spendy… 2016-01-03 10:06:00          2 2016-01-03 10:06:00 2016-01-03 10:00:00
#> 7 Spendy… 2016-01-03 10:15:00          3 2016-01-03 10:15:00 2016-01-03 10:00:00
#> # … with 1 more variable: session_id <int>

# Sort of - also drops purchases with no session time
# In mine, the inner join only applies to `by`, not `i`
# website[paypal, roll = TRUE, nomatch = NULL]

# For each of the purchases that have a website session,
# find the last time they visited the website. Also appends
# website sessions that had no purchases to the end.
slide_right_join(paypal_tbl, website_tbl, "join_time", "name")
#> # A tibble: 9 x 6
#> # Groups:   name [5]
#>   name    purchase_time       payment_id join_time           session_start_time 
#>   <chr>   <dttm>                   <int> <dttm>              <dttm>             
#> 1 Error-… 2016-01-03 08:02:00          7 2016-01-03 08:02:00 NA                 
#> 2 Freque… 2016-01-03 19:28:00          4 2016-01-03 19:28:00 2016-01-03 19:22:00
#> 3 Freque… 2016-01-08 20:33:00          5 2016-01-08 20:33:00 2016-01-08 20:22:00
#> 4 Freque… 2016-01-10 17:46:00          6 2016-01-10 17:46:00 2016-01-10 17:36:00
#> 5 Indeci… 2016-01-08 19:10:00          1 2016-01-08 19:10:00 2016-01-08 19:01:00
#> 6 Spendy… 2016-01-03 10:06:00          2 2016-01-03 10:06:00 2016-01-03 10:00:00
#> 7 Spendy… 2016-01-03 10:15:00          3 2016-01-03 10:15:00 2016-01-03 10:00:00
#> 8 Visito… NA                          NA NA                  2016-01-01 09:10:00
#> 9 Visito… NA                          NA NA                  2016-01-09 02:15:00
#> # … with 1 more variable: session_id <int>

# Combination of left and right (So we get Mom - no session, and Vivian - no purchase)
slide_full_join(paypal_tbl, website_tbl, "join_time", "name")
#> # A tibble: 10 x 6
#> # Groups:   name [6]
#>    name   purchase_time       payment_id join_time           session_start_time 
#>    <chr>  <dttm>                   <int> <dttm>              <dttm>             
#>  1 Error… 2016-01-03 08:02:00          7 2016-01-03 08:02:00 NA                 
#>  2 Frequ… 2016-01-03 19:28:00          4 2016-01-03 19:28:00 2016-01-03 19:22:00
#>  3 Frequ… 2016-01-08 20:33:00          5 2016-01-08 20:33:00 2016-01-08 20:22:00
#>  4 Frequ… 2016-01-10 17:46:00          6 2016-01-10 17:46:00 2016-01-10 17:36:00
#>  5 Indec… 2016-01-08 19:10:00          1 2016-01-08 19:10:00 2016-01-08 19:01:00
#>  6 Mom    2015-12-02 17:58:00          8 2015-12-02 17:58:00 NA                 
#>  7 Spend… 2016-01-03 10:06:00          2 2016-01-03 10:06:00 2016-01-03 10:00:00
#>  8 Spend… 2016-01-03 10:15:00          3 2016-01-03 10:15:00 2016-01-03 10:00:00
#>  9 Visit… NA                          NA NA                  2016-01-01 09:10:00
#> 10 Visit… NA                          NA NA                  2016-01-09 02:15:00
#> # … with 1 more variable: session_id <int>

# For each website session, find the next purchase
# (Francis had two sessions leading up to the same purchase)
slide_left_join(website_tbl, paypal_tbl, "join_time", "name", type = "nocb")
#> # A tibble: 16 x 6
#> # Groups:   name [5]
#>    name   session_start_time  session_id join_time           purchase_time      
#>    <chr>  <dttm>                   <int> <dttm>              <dttm>             
#>  1 Error… 2016-01-04 19:12:00         13 2016-01-04 19:12:00 NA                 
#>  2 Error… 2016-01-04 21:05:00         14 2016-01-04 21:05:00 NA                 
#>  3 Frequ… 2016-01-02 13:09:00          7 2016-01-02 13:09:00 2016-01-03 19:28:00
#>  4 Frequ… 2016-01-03 19:22:00          8 2016-01-03 19:22:00 2016-01-03 19:28:00
#>  5 Frequ… 2016-01-08 08:44:00          9 2016-01-08 08:44:00 2016-01-08 20:33:00
#>  6 Frequ… 2016-01-08 20:22:00         10 2016-01-08 20:22:00 2016-01-08 20:33:00
#>  7 Frequ… 2016-01-10 17:36:00         11 2016-01-10 17:36:00 2016-01-10 17:46:00
#>  8 Frequ… 2016-01-15 16:56:00         12 2016-01-15 16:56:00 NA                 
#>  9 Indec… 2016-01-01 11:01:00          1 2016-01-01 11:01:00 2016-01-08 19:10:00
#> 10 Indec… 2016-01-02 08:59:00          2 2016-01-02 08:59:00 2016-01-08 19:10:00
#> 11 Indec… 2016-01-05 18:18:00          3 2016-01-05 18:18:00 2016-01-08 19:10:00
#> 12 Indec… 2016-01-07 19:03:00          4 2016-01-07 19:03:00 2016-01-08 19:10:00
#> 13 Indec… 2016-01-08 19:01:00          5 2016-01-08 19:01:00 2016-01-08 19:10:00
#> 14 Spend… 2016-01-03 10:00:00          6 2016-01-03 10:00:00 2016-01-03 10:06:00
#> 15 Visit… 2016-01-01 09:10:00         15 2016-01-01 09:10:00 NA                 
#> 16 Visit… 2016-01-09 02:15:00         16 2016-01-09 02:15:00 NA                 
#> # … with 1 more variable: payment_id <int>
```
