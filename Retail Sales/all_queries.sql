CREATE TABLE Customers (CustomerID INT PRIMARY KEY,CustomerName VARCHAR(100) NOT NULL,SignupDate DATE NOT NULL);

CREATE TABLE Stores (StoreID INT PRIMARY KEY,StoreName VARCHAR(100) NOT NULL,RegionRaw VARCHAR(20) NOT NULL);

CREATE TABLE Products (ProductID INT PRIMARY KEY,ProductName VARCHAR(100) NOT NULL,Category    VARCHAR(50) NOT NULL);

CREATE TABLE Orders (OrderID INT PRIMARY KEY,OrderDate   DATE NOT NULL,CustomerID INT NOT NULL,StoreID INT NOT NULL,OrderStatus VARCHAR(20) NOT NULL);

CREATE TABLE OrderItems (OrderItemID INT NOT NULL,OrderID INT NOT NULL,ProductID   INT NOT NULL,Quantity INT NOT NULL,UnitPrice DECIMAL(10, 2) NOT NULL,LoadedAt DATETIME NOT NULL);

CREATE TABLE Returns (ReturnID INT PRIMARY KEY,OrderItemID INT NOT NULL,ReturnDate     DATE NOT NULL,ReturnQuantity INT NOT NULL);

-- Q1: Standardize store regions
CREATE TABLE Regions (RegionID INT PRIMARY KEY,RegionName VARCHAR(50) NOT NULL UNIQUE);

INSERT INTO Regions (RegionID, RegionName) VALUES (1, 'North'),(2, 'South'),(3, 'West');

ALTER TABLE Stores ADD COLUMN RegionID INT;

UPDATE Stores SET RegionID = CASE WHEN UPPER(TRIM(RegionRaw)) IN ('N', 'NORTH') THEN 1 WHEN UPPER(TRIM(RegionRaw)) IN ('S', 'SOUTH') THEN 2 WHEN UPPER(TRIM(RegionRaw)) IN ('W', 'WEST')  THEN 3 END WHERE StoreID IS NOT NULL;

ALTER TABLE Stores ADD CONSTRAINT fk_stores_region FOREIGN KEY (RegionID) REFERENCES Regions(RegionID);

-- Q2: Remove duplicate order lines
CREATE TABLE OrderItems_Clean AS SELECT * FROM OrderItems;

DELETE o1 FROM OrderItems_Clean o1 INNER JOIN OrderItems_Clean o2 ON o1.OrderItemID = o2.OrderItemID AND o1.LoadedAt < o2.LoadedAt;

ALTER TABLE OrderItems_Clean ADD PRIMARY KEY (OrderItemID);

SELECT 'OrderItems (raw)' AS TableName, COUNT(*) AS RowCount FROM OrderItems UNION ALL SELECT 'OrderItems_Clean' AS TableName, COUNT(*) AS RowCount FROM OrderItems_Clean;

SELECT * FROM OrderItems_Clean WHERE OrderItemID = 5003;


-- 4. Orders with matching customers
SELECT o.OrderID,o.CustomerID,c.CustomerName FROM Orders o INNER JOIN Customers c ON o.CustomerID = c.CustomerID ORDER BY o.OrderID;

-- 5. Orders with unmatched customer IDs
SELECT o.OrderID,o.CustomerID FROM Orders o LEFT JOIN Customers c ON o.CustomerID = c.CustomerID WHERE c.CustomerID IS NULL ORDER BY o.OrderID;

--6 – Customers with no orders
SELECT c.CustomerID,c.CustomerName FROM Customers c LEFT JOIN Orders o ON c.CustomerID = o.CustomerID WHERE o.OrderID IS NULL ORDER BY c.CustomerID;

-- 7 – Order lines with multiple returns
SELECT r.OrderItemID,COUNT(r.ReturnID) AS ReturnTransactionCount,SUM(r.ReturnQuantity) AS TotalReturnedUnits FROM Returns r INNER JOIN OrderItems_Clean oi ON r.OrderItemID = oi.OrderItemID GROUP BY r.OrderItemID HAVING COUNT(r.ReturnID) > 1 ORDER BY r.OrderItemID;

--8 – Regional sales and returns
--Query 1: Completed Order Count & Gross Sales by Region (October 2026)
SELECT r.RegionName,COUNT(DISTINCT o.OrderID) AS CompletedOrderCount,SUM(oi.Quantity * oi.UnitPrice) AS GrossSalesUSD FROM Orders o INNER JOIN Stores s ON o.StoreID = s.StoreID INNER JOIN Regions r ON s.RegionID = r.RegionID INNER JOIN OrderItems_Clean oi ON o.OrderID = oi.OrderID WHERE o.OrderStatus = 'Completed' AND o.OrderDate >= '2026-10-01' AND o.OrderDate <  '2026-11-01' GROUP BY r.RegionName ORDER BY r.RegionName;

--Query 2: Return Value by Region (Returns Processed in October 2026)
SELECT r.RegionName,COALESCE(SUM(ret.ReturnQuantity * oi.UnitPrice), 0.00) AS ReturnValueUSD FROM Regions r LEFT JOIN Stores s ON r.RegionID = s.RegionID LEFT JOIN Orders o ON s.StoreID = o.StoreID AND o.OrderStatus = 'Completed' LEFT JOIN OrderItems_Clean oi ON o.OrderID = oi.OrderID LEFT JOIN Returns ret ON oi.OrderItemID = ret.OrderItemID AND ret.ReturnDate >= '2026-10-01' AND ret.ReturnDate <  '2026-11-01' GROUP BY r.RegionName ORDER BY r.RegionName;


--10 – Compare stores within each region

--Query 1: October 2026 Gross Sales by Store
SELECT r.RegionName,s.StoreID,s.StoreName,COALESCE(SUM(oi.Quantity * oi.UnitPrice), 0.00) AS GrossSalesUSD FROM Stores s INNER JOIN Regions r ON s.RegionID = r.RegionID LEFT JOIN Orders o ON s.StoreID = o.StoreID AND o.OrderStatus = 'Completed' AND o.OrderDate >= '2026-10-01' AND o.OrderDate <  '2026-11-01' LEFT JOIN OrderItems_Clean oi ON o.OrderID = oi.OrderID GROUP BY r.RegionName, s.StoreID, s.StoreName ORDER BY r.RegionName, s.StoreID;

--Query 2: October 2026 Return Value by Store
SELECT r.RegionName,s.StoreID,s.StoreName,COALESCE(SUM(ret.ReturnQuantity * oi.UnitPrice), 0.00) AS ReturnValueUSD FROM Stores s INNER JOIN Regions r ON s.RegionID = r.RegionID LEFT JOIN Orders o ON s.StoreID = o.StoreID AND o.OrderStatus = 'Completed' LEFT JOIN OrderItems_Clean oi ON o.OrderID = oi.OrderID LEFT JOIN Returns ret ON oi.OrderItemID = ret.OrderItemID AND ret.ReturnDate >= '2026-10-01' AND ret.ReturnDate <  '2026-11-01' GROUP BY r.RegionName, s.StoreID, s.StoreName ORDER BY r.RegionName, s.StoreID;

--11 – Find the category with the highest return value
SELECT p.Category,SUM(ret.ReturnQuantity * oi.UnitPrice) AS ReturnValueUSD,ROUND(100.0 * SUM(ret.ReturnQuantity * oi.UnitPrice) / NULLIF(tot.TotalReturnUSD, 0),2) AS ShareOfNorthReturnsPct FROM Returns ret INNER JOIN OrderItems_Clean oi ON ret.OrderItemID = oi.OrderItemID INNER JOIN Orders o ON oi.OrderID = o.OrderID INNER JOIN Stores s ON o.StoreID = s.StoreID INNER JOIN Regions r ON s.RegionID = r.RegionID INNER JOIN Products p ON oi.ProductID = p.ProductID
CROSS JOIN (SELECT SUM(ret2.ReturnQuantity * oi2.UnitPrice) AS TotalReturnUSD FROM Returns ret2 INNER JOIN OrderItems_Clean oi2 ON ret2.OrderItemID = oi2.OrderItemID INNER JOIN Orders o2 ON oi2.OrderID = o2.OrderID INNER JOIN Stores s2 ON o2.StoreID = s2.StoreID INNER JOIN Regions r2 ON s2.RegionID = r2.RegionID WHERE r2.RegionName = 'North' AND o2.OrderStatus = 'Completed' AND ret2.ReturnDate >= '2026-10-01' AND ret2.ReturnDate <  '2026-11-01'
) to WHERE r.RegionName = 'North' AND o.OrderStatus = 'Completed' AND ret.ReturnDate >= '2026-10-01' AND ret.ReturnDate <  '2026-11-01' GROUP BY p.Category, tot.TotalReturnUSD ORDER BY ReturnValueUSD DESC, p.Category ASC;


