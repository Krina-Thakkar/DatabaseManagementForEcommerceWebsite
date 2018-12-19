# Trigger - 1 --------------------------------------------------------
select * from item;
select * from order_has_item;
insert into order_has_item values (4,4,1,4,3,2,PriceInOrder(order_has_item.Item_ProductID),3,DiscountInOrder(order_has_item.Item_ProductID));

Delimiter $$
create trigger Product_Quantity	
	After INSERT on bostoncraiglist.order_has_item
	for each row 
Begin
	set @productId = NEW.Item_ProductID;
	set @newQuantity = NEW.Quantity;
    update bostoncraiglist.Item set QuantityPerUnit = QuantityPerUnit - @newQuantity
    where Item.ProductID = @productID;
END;
$$

# Trigger - 2 -----------------------------------------------------
select * from shipment;
select * from orderdetail;
Delimiter $$
create trigger updateOrderStatus	
	After UPDATE on bostoncraiglist.shipment
	for each row 
Begin
	UPDATE orderdetail
    SET OrderStatus = "Delivered"
    WHERE orderdetail.OrderID = new.ORDER_OrderID;
END;
$$

# View - 1 ------------------------------------------------------------

create view CustomerOrderHistory
as
Select Customer.CustomerName AS 'Customer Name', item.productName AS 'Product Name', ordereditem.Quantity AS 'Quantity', ordereditem.ORDER_OrderID AS 'Order Number',od.OrderStatus AS 'Order Status', supplier.SupplierName AS 'Supplier Name', supplier.SupplierPhoneNo AS 'Supplier Contact Number', sum((ordereditem.Price*(1-(ordereditem.Discount/100))*ordereditem.Quantity)) AS 'Total Price After Discount'
from customer JOIN
order_has_item ordereditem
on customer.customerID = ordereditem.order_customer_customerID
JOIN item 
ON ordereditem.Item_ProductID = item.ProductID
JOIN orderdetail od
ON ordereditem.ORDER_OrderID = od.OrderID
JOIN shipment
ON shipment.ORDER_OrderID = ordereditem.ORDER_OrderID
JOIN supplier
ON shipment.SUPPLIER_SupplierID = supplier.SupplierID
group by Customer.CustomerName,ordereditem.ORDER_OrderID;

select * from CustomerOrderHistory;

# View - 2 ------------------------------------------------------------------
create view RevenueFromEachCustomer
as
Select Customer.CustomerName AS 'Customer Name',sum((ordereditem.Price*(1-(ordereditem.Discount/100))*ordereditem.Quantity)) AS 'Total Revenue From Each Customer'
from customer JOIN
order_has_item ordereditem
on customer.customerID = ordereditem.order_customer_customerID
group by Customer.CustomerName WITH ROLLUP;

select * from RevenueFromEachCustomer;

# UDF - 1 -----------------------------------------------------------------
select * from order_has_item;
DELIMITER //
Create Function PriceInOrder(ProductID int)
Returns float
DETERMINISTIC
Begin
	declare price float;
	select item.UnitPrice into price  from item  where item.ProductID = ProductID;
	return price;
END;
//

# UDF - 2 ------------------------------------------------------------------
DELIMITER //
Create Function DiscountInOrder(ProductID int)
Returns float
DETERMINISTIC
Begin
    declare discount float;
    select item.DiscountPercent into discount  from item  where item.ProductID = ProductID;
	return discount;
END;
//

Select * from order_has_item;

insert into order_has_item values (2,2,3,2,1,1,PriceInOrder(order_has_item.Item_ProductID),1,DiscountInOrder(order_has_item.Item_ProductID));
insert into order_has_item values (3,3,2,3,2,2,PriceInOrder(order_has_item.Item_ProductID),2,DiscountInOrder(order_has_item.Item_ProductID));
insert into order_has_item values (4,4,1,4,3,2,PriceInOrder(order_has_item.Item_ProductID),3,DiscountInOrder(order_has_item.Item_ProductID));
insert into order_has_item values (6,1,2,6,5,3,PriceInOrder(order_has_item.Item_ProductID),2,DiscountInOrder(order_has_item.Item_ProductID));
insert into order_has_item values (7,3,1,7,6,3,PriceInOrder(order_has_item.Item_ProductID),3,DiscountInOrder(order_has_item.Item_ProductID));


# Procedure - 1 ----------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE TotalRevenuePerDay(IN OrderDate date)
BEGIN
    select ordereditem.ORDER_OrderID AS OrderID,sum((ordereditem.Price*(1-(ordereditem.Discount/100))*ordereditem.Quantity)) AS TotalRevenue from orderdetail JOIN
    order_has_item ordereditem
    on orderdetail.OrderID = ordereditem.Order_OrderID
    where orderdetail.OrderPlacedDate = OrderDate
    group by ordereditem.ORDER_OrderID;
END;
$$

call TotalRevenuePerDay("2018-12-01");

# Procedure - 2 -----------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE productBasedOnCategory(IN categoryName varchar(45))
BEGIN
	select item.ProductName, item.QuantityPerUnit from item
    JOIN category
    on item.CATEGORY_CategoryID = category.CategoryID
    where category.CategoryName = categoryName;
END;
$$

drop procedure productBasedOnCategory;

call productBasedOnCategory("electronics");

# Procedure - 3 -------------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE discountOnProduct(IN pname varchar(30))
BEGIN
    select ProductName, UnitPrice AS 'Original Price',(UnitPrice*(1-(DiscountPercent/100))) AS 'Discounted Price' From item
    where ProductName = pname ;
END;
$$

drop procedure discountOnProduct;

call discountOnProduct('CellPhone');

# Index -------------------------------------------------------------------------------
create index prouctName_index on item(ProductName) USING BTREE;
create index categoryName_index on category(CategoryName) USING BTREE;

# Grant Priviliges ---------------------------------------------------------------------
create user 'customer'@localhost identified by 'customer';
GRANT ALL on bostoncraiglist.cart to 'customer'@localhost;
GRANT ALL on bostoncraiglist.orderdetail to 'customer'@localhost;
GRANT ALL on bostoncraiglist.payment to 'customer'@localhost;
GRANT ALL on bostoncraiglist.carddetails to 'customer'@localhost;

create user 'supplier'@localhost identified by 'supplier';
GRANT select on bostoncraiglist.orderdetail to 'supplier'@localhost;
GRANT ALL on bostoncraiglist.shipment to 'supplier'@localhost;
GRANT ALL on bostoncraiglist.item to 'supplier'@localhost;

# Transaction - 1 -------------------------------------------------------------
START TRANSACTION READ ONLY;
BEGIN;
INSERT INTO `bostoncraiglist`.`ITEM`
(`ProductID`, `ProductName`, `QuantityPerUnit`, `UnitPrice`, `DiscountPercent`, `CATEGORY_CategoryID`) 
VALUES ('7', 'Laptop', '100', '600', '10', '2');
SELECT * FROM ITEM;
COMMIT;
END;

# Transaction - 2 -------------------------------------------------------------
START TRANSACTION READ WRITE;
INSERT INTO `bostoncraiglist`.`cart_has_item` (`CART_CartID`, `CART_CUSTOMER_CustomerID`, `ITEM_ProductID`) 
VALUES ('1', '1', '5');
SELECT * FROM cart_has_item;
ROLLBACK;
INSERT INTO `bostoncraiglist`.`cart_has_item` (`CART_CartID`, `CART_CUSTOMER_CustomerID`, `ITEM_ProductID`) 
VALUES ('4', '4', '6');
SELECT * FROM cart_has_item;
COMMIT;

# Full text search
CREATE TABLE `address1` (
  `AddressID` int(10) unsigned NOT NULL,
  `StreetName` varchar(70) NOT NULL,
  `City` varchar(20) NOT NULL,
  `State` varchar(20) NOT NULL,
  `PostalCode` varchar(5) NOT NULL,
  PRIMARY KEY (`AddressID`),
  FULLTEXT(City,State)
) ENGINE=InnoDB;

INSERT INTO `address1` VALUES (1,'Boylston St','Boston','MA','02215'),(2,'Francis St','Albany','NY','04213'),(3,'Portland St','Los Angeles','CA','90007'),(4,'Hemenway St','Boston','MA','02115');

SELECT * FROM address1
WHERE MATCH (City,State)
AGAINST ('Boston' IN NATURAL LANGUAGE MODE);
