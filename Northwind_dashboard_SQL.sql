/* SQL query for Northwind dashboard self-project */

-- 1. Retrive all the Order table with according detail (unit price, discount ...)--
select *
from Northwind.dbo.Orders o1
join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID;

/* 2. Rerive top of Dairy Products group that have most of revenue in Austria
in 2016 */

-- The money flow in which products in Dairy Products category--
--Filter productID equivalent to DIARY PRODUCTS categories--
with filter_cates as (select 
	od1.*, p1.productName,
	CASE
		WHEN cate1.CategoryName = 'Dairy Products' THEN 1
		ELSE 0
	END AS filter_cate
from Northwind.dbo.OrderDetails od1
inner join Northwind.dbo.Products p1
on od1.ProductID = p1.ProductID
inner join Northwind.dbo.Categories cate1
on p1.CategoryID = cate1.CategoryID),
-- Caculate the revenue on each order, in Austria, 2016 --
full_bill as (select 
	YEAR(CONVERT(Date,o1.OrderDate)) as year_order,
	o1.CustomerID, o1.EmployeeID,
	fc.OrderID, fc.ProductID, fc.ProductName,
	sum(o1.Freight) as ship_fee,
	sum((fc.UnitPrice-(fc.UnitPrice*fc.Discount))*fc.Quantity) as bill,
	sum((fc.UnitPrice-(fc.UnitPrice*fc.Discount))*fc.Quantity) - sum(o1.Freight) as net_bill
from filter_cates fc
inner join Northwind.dbo.Orders o1
on fc.OrderID = o1.OrderID
where o1.ShipCountry = 'Austria'
and YEAR(CONVERT(Date,o1.OrderDate)) = 2016
and fc.ProductID in (select productID from filter_cates where filter_cate = 1)
group by o1.CustomerID, o1.OrderDate, fc.OrderID, fc.ProductID, fc.ProductName, o1.Freight, o1.EmployeeID)

select 
	fbl.*, e1.LastName
from full_bill fbl
inner join Northwind.dbo.Employees e1
on fbl.EmployeeID = e1.EmployeeID
order by net_bill DESC;

/* 3. Contribute of Europe's revenue in each sub-country in 2015, 2016 */
-- SQL query to track sales amount of specific Product Categories in specific periods --
with cte1 as (select 
	od1.ProductID,
	YEAR(CONVERT(date, o1.orderDate)) as year_order,
	o1.ShipCountry as Country,
	sum((od1.UnitPrice-(od1.UnitPrice*od1.Discount))*od1.Quantity) as total_amount
from Northwind.dbo.Orders o1
inner join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID
where YEAR(CONVERT(date, o1.orderDate)) between 2015 and 2016
GROUP BY YEAR(CONVERT(date, o1.orderDate)), o1.ShipCountry, od1.ProductID)

select 
	c1.year_order, c1.Country, cate1.CategoryName,
	c1.total_amount
from cte1 c1
join Northwind.dbo.Products p1
on c1.ProductID = p1.ProductID
join Northwind.dbo.Categories cate1
on p1.CategoryID = cate1.CategoryID
where cate1.CategoryName in ('Dairy Products','Confections');
/* Note: The above query return the total overview of all sub-country in 2015, 2016
In PowerBI, I've created the sub-table 'country' and look-up country information from that */

/*4. The query rertive performance of employee (combine SQL and PBI edit query) */
with employee_rev_2014 as (select 
	o1.EmployeeID,
	sum((od1.UnitPrice-(od1.UnitPrice*od1.Discount))*od1.Quantity) as revenue_2014
from Northwind.dbo.Orders o1
inner join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID
where YEAR(CONVERT(date,o1.OrderDate)) = 2014
group by o1.EmployeeID),

employee_rev_2015 as (select 
	o1.EmployeeID,
	sum((od1.UnitPrice-(od1.UnitPrice*od1.Discount))*od1.Quantity) as revenue_2015
from Northwind.dbo.Orders o1
inner join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID
where YEAR(CONVERT(date,o1.OrderDate)) = 2015
group by o1.EmployeeID),

employee_rev_2016 as (select 
	o1.EmployeeID,
	sum((od1.UnitPrice-(od1.UnitPrice*od1.Discount))*od1.Quantity) as revenue_2016
from Northwind.dbo.Orders o1
inner join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID
where YEAR(CONVERT(date,o1.OrderDate)) = 2016
group by o1.EmployeeID)

select 
	er14.EmployeeID,
	empl.LastName,
	empl.HireDate,
	er14.revenue_2014,
	er15.revenue_2015,
	er16.revenue_2016
from employee_rev_2014 er14
inner join employee_rev_2015 er15
on er14.EmployeeID = er15.EmployeeID
inner join employee_rev_2016 er16
on er14.EmployeeID = er16.EmployeeID
inner join Northwind.dbo.Employees empl
on er14.EmployeeID = empl.EmployeeID;

/*IN Power Query editor, I've filtered out Manager line and keep the remain to chart */

/* 5. Retrive the revenue sum-up of manager line
a, Retrive the hireachy of employee's organization
b, Caculate the revenue sum-up according to the hireachy */

-- Code to caculate sum-up revenue--
-- Check level management in organization--
with hr_management as (
select EmployeeID, LastName, FirstName, Title,ReportsTo as manager_id, 0 as manager_level
from Northwind.dbo.Employees
where ReportsTo is null
UNION ALL
select e1.EmployeeID, e1.LastName, e1.FirstName, e1.Title, e1.ReportsTo as manager_id, manager_level+1
from Northwind.dbo.Employees e1
join hr_management a
on e1.ReportsTo = a.employeeID),
-- Caculate overview total revenue--
Raw_1 as (select 
	o1.EmployeeID,
	o1.OrderDate,
	sum((od1.UnitPrice-(od1.UnitPrice*od1.Discount))*od1.Quantity) as total_bill				
from Northwind.dbo.Orders o1
inner join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID
group by o1.EmployeeID, o1.OrderDate),
-- From these, caculate particular for manager line, over year --
bill_2014 as (select 
	r1.EmployeeID,
	sum(total_bill) as self_bill,
	(select sum(total_bill)
	from hr_management hr, Raw_1 r1
	where hr.EmployeeID = r1.EmployeeID
	and hr.manager_level > 0
	and YEAR(CONVERT(date,OrderDate))=2014) as bill_2014,
	sum(total_bill) + (select sum(total_bill)
						from hr_management hr, Raw_1 r1
						where hr.EmployeeID = r1.EmployeeID
						and hr.manager_level > 0
						and YEAR(CONVERT(date,OrderDate))=2014) as final_bill_2014
from hr_management hr
join Raw_1 r1
on hr.EmployeeID = r1.EmployeeID
where manager_level = 0
and YEAR(CONVERT(date,OrderDate))=2014
group by r1.EmployeeID
UNION ALL
select 
	r1.EmployeeID,
	sum(total_bill) as self_bill,
	(select sum(total_bill)
	from hr_management hr, Raw_1 r1
	where hr.EmployeeID = r1.EmployeeID
	and hr.manager_id = (select EmployeeID from hr_management where Title like '%manager%')
	and YEAR(CONVERT(date,OrderDate))=2014) as bill_2014,
	sum(total_bill) + (select sum(total_bill)
						from hr_management hr, Raw_1 r1
						where hr.EmployeeID = r1.EmployeeID
						and hr.manager_id = (select EmployeeID from hr_management where Title like '%manager%')
						and YEAR(CONVERT(date,OrderDate))=2014) as final_bill_2014
from hr_management hr
join Raw_1 r1
on hr.EmployeeID = r1.EmployeeID
where hr.EmployeeID = (select EmployeeID from hr_management where Title like '%manager%')
and YEAR(CONVERT(date,OrderDate))=2014
group by r1.EmployeeID),

bill_2015 as (select 
	r1.EmployeeID,
	sum(total_bill) as self_bill_2015,
	(select sum(total_bill)
	from hr_management hr, Raw_1 r1
	where hr.EmployeeID = r1.EmployeeID
	and hr.manager_level > 0
	and YEAR(CONVERT(date,OrderDate))=2015) as bill_2015,
	sum(total_bill) + (select sum(total_bill)
						from hr_management hr, Raw_1 r1
						where hr.EmployeeID = r1.EmployeeID
						and hr.manager_level > 0
						and YEAR(CONVERT(date,OrderDate))=2015) as final_bill_2015
from hr_management hr
join Raw_1 r1
on hr.EmployeeID = r1.EmployeeID
where manager_level = 0
and YEAR(CONVERT(date,OrderDate))=2015
group by r1.EmployeeID
UNION ALL
select 
	r1.EmployeeID,
	sum(total_bill) as self_bill_2015,
	(select sum(total_bill)
	from hr_management hr, Raw_1 r1
	where hr.EmployeeID = r1.EmployeeID
	and hr.manager_id = (select EmployeeID from hr_management where Title like '%manager%')
	and YEAR(CONVERT(date,OrderDate))=2015) as bill_2015,
	sum(total_bill) + (select sum(total_bill)
						from hr_management hr, Raw_1 r1
						where hr.EmployeeID = r1.EmployeeID
						and hr.manager_id = (select EmployeeID from hr_management where Title like '%manager%')
						and YEAR(CONVERT(date,OrderDate))=2015) as final_bill_2014
from hr_management hr
join Raw_1 r1
on hr.EmployeeID = r1.EmployeeID
where hr.EmployeeID = (select EmployeeID from hr_management where Title like '%manager%')
and YEAR(CONVERT(date,OrderDate))=2015
group by r1.EmployeeID),

bill_2016 as (select 
	r1.EmployeeID,
	sum(total_bill) as self_bill_2016,
	(select sum(total_bill)
	from hr_management hr, Raw_1 r1
	where hr.EmployeeID = r1.EmployeeID
	and hr.manager_level > 0
	and YEAR(CONVERT(date,OrderDate))=2016) as bill_2016,
	sum(total_bill) + (select sum(total_bill)
						from hr_management hr, Raw_1 r1
						where hr.EmployeeID = r1.EmployeeID
						and hr.manager_level > 0
						and YEAR(CONVERT(date,OrderDate))=2016) as final_bill_2016
from hr_management hr
join Raw_1 r1
on hr.EmployeeID = r1.EmployeeID
where manager_level = 0
and YEAR(CONVERT(date,OrderDate))=2016
group by r1.EmployeeID
UNION ALL
select 
	r1.EmployeeID,
	sum(total_bill) as self_bill_2016,
	(select sum(total_bill)
	from hr_management hr, Raw_1 r1
	where hr.EmployeeID = r1.EmployeeID
	and hr.manager_id = (select EmployeeID from hr_management where Title like '%manager%')
	and YEAR(CONVERT(date,OrderDate))=2016) as bill_2016,
	sum(total_bill) + (select sum(total_bill)
						from hr_management hr, Raw_1 r1
						where hr.EmployeeID = r1.EmployeeID
						and hr.manager_id = (select EmployeeID from hr_management where Title like '%manager%')
						and YEAR(CONVERT(date,OrderDate))=2016) as final_bill_2016
from hr_management hr
join Raw_1 r1
on hr.EmployeeID = r1.EmployeeID
where hr.EmployeeID = (select EmployeeID from hr_management where Title like '%manager%')
and YEAR(CONVERT(date,OrderDate))=2016
group by r1.EmployeeID)
-- Combine the result--
select 
	b2014.EmployeeID,
	b2014.final_bill_2014,
	b2015.final_bill_2015,
	b2016.final_bill_2016
from bill_2014 b2014, bill_2015 b2015, bill_2016 b2016
where b2014.EmployeeID = b2015.EmployeeID
and b2014.EmployeeID = b2016.EmployeeID;

/*6. Tracking the late delivered percentage */
-- Late orders: late orders/ total orders --
/* Step 1: Create the source virtual table from Orders but add filter 
where order have ShippedDate over RequiredDate */
with source1 as (select 
	*,
	CASE
		WHEN CONVERT(DATE,ShippedDate) >= CONVERT(DATE, RequiredDate) THEN 1
		ELSE 0
	END AS filter6
from Northwind.dbo.Orders),
/*Step 2: Create two dividual table: Total_orders and Late_orders,
monitoring when process data when/ when not satify delivered condition,
we will join these two table after*/
total_order as (select 
	s1.EmployeeID,
	e.LastName,
	count(s1.OrderID) as AllOrders
from source1 s1
inner join Northwind.dbo.Employees e
on s1.EmployeeID = e.EmployeeID
group by s1.EmployeeID, e.LastName),

late_orders as (select 
	s1.EmployeeID,
	e.LastName,
	count(s1.OrderID) as LateOrders
from source1 s1
inner join Northwind.dbo.Employees e
on s1.EmployeeID = e.EmployeeID
where filter6 = 1
group by s1.EmployeeID, e.LastName)
/*Step 3: Left-join two tables above, to get the final result */
select 
	t1.EmployeeID,
	t1.LastName,
	t1.AllOrders,
	ISNULL(l1.LateOrders,0) as LateOrders,
	ISNULL(ROUND(CAST(LateOrders as float)/CAST(t1.AllOrders as float),2),0) as last_percent
from total_order t1
left join late_orders l1
on t1.EmployeeID = l1.EmployeeID;

/*7. Segment status
Note: I've retrived revenue over year in PBI and make box-plot to 
get the vision about how the revenue contribute.
When I saw that almost over 3 year, the orders booking gather on range of ~$5000, 
I've categorized the list where which customers spent less than $5000, it's Medium */

--Segment over years--
WITH Raw_ as (select 
	o1.CustomerID,
	o1.OrderDate,
	sum((od1.UnitPrice-(od1.UnitPrice*od1.Discount))*od1.Quantity) as total_bill				
from Northwind.dbo.Orders o1
inner join Northwind.dbo.OrderDetails od1
on o1.OrderID = od1.OrderID
group by o1.CustomerID, o1.OrderDate),

segment_filter as (select *,
	sum(total_bill) as final_bill,
	CASE
		WHEN sum(total_bill) >= 0 AND sum(total_bill) <1000 THEN 'Low'
		WHEN sum(total_bill) >= 1000 AND sum(total_bill) <5000 THEN 'Medium'
		WHEN sum(total_bill) >= 5000 AND sum(total_bill) <10000 THEN 'High'
		ELSE 'VIP'
	END AS segment
from Raw_
group by CustomerID, total_bill,OrderDate),

seg_2014 as (select 
	segment,
	COUNT(distinct CustomerID) as seg_2014
from segment_filter
where YEAR(CONVERT(date,OrderDate))=2014
group by segment),

seg_2015 as (select 
	segment,
	COUNT(distinct CustomerID) as seg_2015
from segment_filter
where YEAR(CONVERT(date,OrderDate))=2015
group by segment),

seg_2016 as (select 
	segment,
	COUNT(distinct CustomerID) as seg_2016
from segment_filter
where YEAR(CONVERT(date,OrderDate))=2016
group by segment)

select
	sg2016.segment,
	seg_2014, seg_2015, seg_2016
from seg_2016 sg2016
left join seg_2015 sg2015
on sg2016.segment = sg2015.segment
left join seg_2014 sg2014
on  sg2016.segment = sg2014.segment;

/*7. Tracking the sell area of each staff */
select 
	EmployeeID,
	ShipCountry
from Northwind.dbo.Orders
group by EmployeeID, ShipCountry;
/*Note: Later, I've looked-up from sub-country to country and monitor on PBI */