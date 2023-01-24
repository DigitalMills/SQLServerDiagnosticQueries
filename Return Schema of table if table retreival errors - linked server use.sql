--Declare @PO int = --1817395; --1872443 1824351 1817395
--Declare @Batch int = 21;
--Declare @1stFilter varchar(30) = 'ProductType'
--Declare @2ndFilter varchar(30) = 'Manufacturer';
--declare @LocsVar varchar(20) --= 'BAY-3'

--Choose PO or RP Bay
IF (isnumeric(@PO) = 1 and @PO is not null)
BEGIN

;with Data as (
select distinct tbpopart.[Stock Code], tbpopart.Manufacturer, tbPOPart.Description, SUM(tbGRNPart.Received) Qty, TagID,
 1 Ctr,
	case
	when BusinessUnitId = 1 then 'Laptop'
	when BusinessUnitId = 5 then 'Servers'
	when BusinessUnitId = 10 then 'Desktop'
	when BusinessUnitId = 22 then 'Mobile'
	when BusinessUnitId = 13 then 'PCAccessories'
	end ProductType
	 from tbpo with (nolock)
	inner join tbpopart with (nolock)
	on tbpo.id = tbpopart.DocumentId
	inner join tbGRNPart with (nolock)
	on tbPOPart.id = POPartID
	inner join tbcategories with (nolock)
	on tbCategories.Description = tbPOPart.Category
	where [PO Number] =  @PO
	and BusinessUnitId IN (1,5,10,22,13)
	group by tbpopart.[Stock Code], tbpopart.Manufacturer, tbPOPart.Description, BusinessUnitId, TagID
),


CTE_RECUR 
  AS
  (
  SELECT [stock code],Manufacturer,Description, Qty, producttype, tagid, Ctr FROM Data
  UNION ALL
  SELECT [stock code],Manufacturer,Description, Qty, producttype, tagid, Ctr + 1 FROM CTE_RECUR WHERE ctr<qty
  )

	  
	  select *, ROW_NUMBER() OVER(ORDER BY (SELECT NULL),  manufacturer, [stock code],
	case @1stFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end
	,	case @2ndFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end, qty asc, tagid, Ctr asc) [Count] into #t1
	  from CTE_RECUR
	order by [stock code],
	case @1stFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end
	,	case @2ndFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end, qty asc, tagid, ctr asc
	option (MAXRECURSION 1000)

	select [stock code], Manufacturer, producttype, description, tagid, count(*) [Quantity], a.Batch from (
	select [stock code], Manufacturer, producttype, description, tagid,  (Row_number()OVER(ORDER BY [count]) - 1 ) / @Batch + 1 [Batch]
	from #t1 with (nolock)
	) a
	group by [stock code], Manufacturer, producttype, description, tagid, batch
	order by a.Batch, [stock code]

	drop table #t1
END

ELSE
BEGIN

declare @sql NVARCHAR(MAX) 
DECLARE @LinkedServer NVARCHAR(50)
DECLARE @RPDAta TABLE	(
						SKU_ID varchaR(50)
						, TAG_Id varchar(50)
						, SKU varchar(128)
						, QTY int
						)

DECLARE RPServers CURSOR FOR
SELECT LinkedServer_Name from tbRP_ActiveServers WITH (NOLOCK) where ISNULL(Active,0) = 1

OPEN RPServers

FETCH NEXT FROM RPServers INTO @LinkedServer

WHILE @@FETCH_STATUS = 0 

BEGIN

SELECT @sql = '
select  I.SKU_ID
        , I.TAG_ID
        , I.USER_DEF_NOTE_1 "SKU"
		, I.QTY_ON_HAND
FROM    INVENTORY I
        Join Location L 
		on I.Location_id = L.LOCATION_ID
		AND L.WORK_ZONE = ''TECH TEAM''
Where   L.Location_ID IN ('''+UPPER(@LocsVar)+''')'


select @sql	= 'SELECT * FROM OPENQUERY('+@LinkedServer+','''+REPLACE(@sql,'''','''''')+''')'

Insert into @RPDAta 
EXEC (@sql)	

FETCH NEXT FROM RPServers INTO @LinkedServer

END

CLOSE RPServers

DEALLOCATE RPServers;


SELECT	SKU [Stock code], P.Manufacturer, P.Description, Qty, Tag_ID TagID, 1 Ctr,
	case
	when BusinessUnitId = 1 then 'Laptop'
	when BusinessUnitId = 5 then 'Servers'
	when BusinessUnitId = 10 then 'Desktop'
	when BusinessUnitId = 22 then 'Mobile'
	when BusinessUnitId = 13 then 'PCAccessories'
	end ProductType
into #data
FROM @RPDAta
LEFT JOIN tbGRNPart GP with (NOLOCK)
Inner Join tbpopart with (NOLOCK)
	ON GP.POPartID = tbPOPart.Id
Inner Join tbpo with (NOLOCK)
	ON tbPOPart.DocumentId = tbpo.Id
	ON [@RPDAta].TAG_Id = Gp.TagID
	AND [@RPDAta].SKU = Gp.[Stock Code]
Inner Join tbProddesc P with (NOLOCK)
	ON [@RPDAta].SKU = P.[Stock Code]
inner join tbcategories with (nolock)
on tbCategories.Description = P.Category
	where BusinessUnitId IN (1,5,10,22,13)
and P.[Stock Controlled] = 1;

with
CTE_RECUR 
  AS
  (
  SELECT [stock code],Manufacturer,Description, Qty, producttype, tagid, Ctr FROM #Data
  UNION ALL
  SELECT [stock code],Manufacturer,Description, Qty, producttype, tagid, Ctr + 1 FROM CTE_RECUR WHERE ctr<qty
  )

	  
	  select *, ROW_NUMBER() OVER(ORDER BY (SELECT NULL),  manufacturer, [stock code],
	case @1stFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end
	,	case @2ndFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end, qty asc, tagid, Ctr asc) [Count] into #t2
	  from CTE_RECUR
	order by [stock code],
	case @1stFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end
	,	case @2ndFilter
		when 'ProductType' then producttype
		when 'Manufacturer' then Manufacturer
		end, qty asc, tagid, ctr asc
	option (MAXRECURSION 1000)

	select [stock code], Manufacturer, producttype, description, tagid, count(*) [Quantity], a.Batch from (
	select [stock code], Manufacturer, producttype, description, tagid,  (Row_number()OVER(ORDER BY [count]) - 1 ) / @Batch + 1 [Batch]
	from #t2 with (nolock)
	) a
	group by [stock code], Manufacturer, producttype, description, tagid, batch
	order by a.Batch, [stock code]

	drop table #t2
	drop table #data

END