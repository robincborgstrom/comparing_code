USE [kvt-db-dev]
GO
/****** Object:  StoredProcedure [dbo].[sp_GenerateSalaryPDFbyID]    Script Date: 6/14/2023 12:16:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_GenerateSalaryPDFbyID]             
(            
 @id bigint,          
 @uuid uniqueidentifier           
)           
AS            
BEGIN         
BEGIN TRY        
BEGIN TRANSACTION        
  select @id as id1,year(start_date) as startyear,uuid as uuid,full_time_allowance,      
  part_time_allowance,      
  meal_allowance,      
  sum_full_time_allowance,      
  sum_mileage_allowance,      
  sum_meal_time_allowance,      
  sum_part_time_allowance,sum_total_allowance,      
  distance,    
  --PDF changes    
  vehicle_type_id,    
  country as country_id,    
  CASE    
  WHEN distance > 0     
  THEN cast(sum_mileage_allowance/distance as decimal(10,2))    
  ELSE 0    
  END as mileage_allowance_cost    
  --PDF changes    
  into #temptable from invoice_allowance       
  where uuid=@uuid and  invoice_id in (select invoice_id from SalariesInvoice where salary_id=@id and uuid=@uuid) 
  and partial_invoice_id in (select partial_invoice_id from SalariesInvoice where salary_id=@id and uuid=@uuid)
  and deleted=0    
      
   select id1,startyear,isnull(sum(meal_allowance),0) as NoOfMealAllownace,      
   isnull(sum(full_time_allowance),0) as NoOfFullTimeAllowance,      
   isnull(sum(part_time_allowance),0) as NoOfPartTimeAllowance,      
   isnull(sum(sum_meal_time_allowance),0) as sum_meal_time_allowance,      
   isnull(sum(sum_full_time_allowance),0) as sum_full_time_allowance,      
   isnull(sum(sum_mileage_allowance),0) as sum_mileage_allowance,       
   isnull(sum(sum_part_time_allowance),0) as sum_part_time_allowance,      
   isnull(sum(sum_total_allowance),0) as sum_total_allowance,      
 isnull(sum(distance),0) as distance into #temptable2 from #temptable group by id1,startyear      
    
 declare @startdate datetime      
 declare @enddate datetime      
      
 select @startdate=min(start_date),@enddate=max(end_date)      
 from invoice_items      
 where uuid=@uuid and deleted=0 and invoice_id in (      
 select invoice_id from salariesinvoice      
 where salary_id =@id and uuid=@uuid)
 and partial_invoice_id in (select partial_invoice_id from salariesinvoice      
 where salary_id =@id and uuid=@uuid)
     
 --PDF Changes    
 -- SELECT distinct salary_id,  salariesinvoices = STUFF(      
 -- ( SELECT ', ' + Convert(varchar,invoice_id) FROM SalariesInvoice  s1        
 --  WHERE s1.salary_id  = s2.salary_id and s1.uuid=s2.uuid        
 --  FOR XML PATH ('')      
 -- ), 1, 1, ''), uuid        
 --INTO #salinvoice1       
 --FROM SalariesInvoice s2 where uuid = @uuid    
 --PDF Changes 
 
 --PartialPay Changes
 SELECT distinct salary_id,  salariesinvoices = STUFF(      
  ( SELECT ', ' + Convert(varchar,invoice_id) FROM SalariesInvoice  s1        
   WHERE s1.salary_id  = s2.salary_id and s1.uuid=s2.uuid        
   FOR XML PATH ('')      
  ), 1, 1, ''),  
  partialInvoiceIds = STUFF(      
  ( SELECT ', ' + Convert(varchar,partial_invoice_id) FROM SalariesInvoice  s1        
   WHERE s1.salary_id  = s2.salary_id and s1.uuid=s2.uuid        
   FOR XML PATH ('')      
  ), 1, 1, ''),  
  uuid as uniqueId       
 INTO #salinvoice1       
 FROM SalariesInvoice s2 where uuid = @uuid;

  WITH dueInvoicesSplit AS (
  SELECT [salary_id], j.[salariesinvoices], j.[partialInvoiceIds],  
  uniqueId, status, s.value as salary_invoice_id, p.value as partial_invoice_id
  FROM #salinvoice1 as j 
  OUTER APPLY STRING_SPLIT(j.[salariesinvoices], ',') AS S
  OUTER APPLY STRING_SPLIT(j.[partialInvoiceIds], ',') AS P
  LEFT JOIN invoice AS i on i.[invoice_id] = S.[value] and i.[partial_invoice_id] = P.[value]
  )
  SELECT [salary_id], [uniqueId], [salariesinvoices], [partialInvoiceIds],
  STRING_AGG([status], ',') AS [all_status] 
  into #salinvoiceX
  FROM dueInvoicesSplit GROUP BY [salary_id], [uniqueId], [salariesinvoices], [partialInvoiceIds]
 --PartialPay Changes
      
  select        
  @startdate as startdate,      
  @enddate as enddate,       
  u.uuid,          
  u.ssn,          
  u.account_number,         
  --u.tax_percentage,          
  s.yelpercentage as yel_percentage,        
  u.leave_bonus_percentage,     
  s.taxpercentage as tax_percentage,     
  --PDF Changes    
  salin.salariesinvoices as invoices,
  salx.all_status as all_status,
  --PDF Changes
  s.sumWithoutTax,
  s.gross_salary,      
  s.net_salary,    
  s.normal_govpay_sum,      
  s.accidental_insurance,      
  s.social_contribution,      
  s.service_cost,      
  s.take_home_pay,         
  s.tax_cost,        
  s.yel_cost,         
  s.id,          
  s.created,          
  s.deductions_sum-s.yel_cost as deductionwithoutYel,         
  u.firstname,        
  u.lastname,        
  u.address,        
  u.zip_code,        
  u.city,    
  u.useMarketName,      
  u.market_name,    
  u.isgovpay,    
  u.isnormalgovpay,    
  isnull(reimbursment_cost,0) as expenses,
  isnull(expenses_cost,0) as allowances,
  isnull(sum_full_time_allowance,0) as sum_full_time_allowance,      
  isnull(sum_mileage_allowance,0) as sum_mileage_allowance ,      
  isnull(sum_part_time_allowance,0) as sum_part_time_allowance,      
  isnull(sum_meal_time_allowance,0) as sum_meal_time_allowance,      
  isnull(sum_total_allowance,0) as sum_total_allowance,      
  isnull(distance,0) as distance ,      
  isnull(NoOfMealAllownace,0) as NoOfMealAllownace,      
  isnull(NoOfFullTimeAllowance,0) as NoOfFullTimeAllowance,      
  isnull(NoOfPartTimeAllowance,0) as NoOfPartTimeAllowance,
  startyear
  from Salary S          
  inner join User_info u on S.uuid=u.uuid        
  left join #temptable2 t on s.id=t.id1    
  --PartialPay Changes    
  left join #salinvoice1 salin on s.id=salin.salary_id
  left join #salinvoiceX salx on s.id=salx.salary_id
  --PartialPay Changes    
  where s.id= @id and s.uuid=@uuid         
   
 declare @salaryyear int    
 select @salaryyear= year(created) from salary where id=@id and uuid=@uuid        
 select isnull(SUM(gross_salary),0) as Totalgross,     
 isnull(SUM(tax_cost),0) Totaltaxcost,    
 isnull(sum(yel_cost),0) Totalyelcost,    
  --PDF Changes    
 isnull(sum(service_cost),0) Totalservicecost    
 --PDF Changes    
 from Salary          
 where year(created)=@salaryyear and uuid=@uuid  and deleted=0      
    and created<=(select created from Salary where id=@id and uuid=@uuid)        
        
 select * from ServiceProvider        
    
select a.id,value,isnuLL(price,0) as price,a.year  from Allowance_cost a    
left outer join CountryFullTimeAllowance c    
on c.id=a.id and country_id=1 where a.id in (4,5) and a.year in (select distinct startyear from #temptable2) order by year asc  
    
--PDF changes    
select vehicle_type_id, type_fi as type,     
isnull(distance,0) as distance, mileage_allowance_cost, sum_mileage_allowance, m.startyear from #temptable m    
left join Allowance_cost c on c.id = m.vehicle_type_id where c.year= m.startyear and sum_mileage_allowance>0 order by vehicle_type_id, year asc
    
select t.country_id, startyear, isnull(sum(full_time_allowance),0) as full_time_allowance,    
isnull(sum(sum_full_time_allowance),0) as sum_full_time_allowance     
into #tempfullAllowancetable from #temptable t    
group by t.country_id, startyear    
    
select country_id, price, country_fi, year     
into #tempUnion from CountryFullTimeAllowance where year in (select distinct startyear from #temptable2)       
UNION    
select region_id as country_id, price, region_fi as country_fi, year from RegionFullTimeAllowance where year in (select distinct startyear from #temptable2) order by year asc   
      
select t.country_id, country_fi as country, full_time_allowance, price, sum_full_time_allowance, startyear    
from #tempfullAllowancetable t    
left join #tempUnion c on c.country_id=t.country_id and c.year=t.startyear   order by country_id,year asc    
    
    
Drop table #temptable    
Drop table #temptable2    
Drop table #salinvoice1    
Drop table #tempfullAllowancetable    
Drop table #tempUnion
Drop table #salinvoiceX
--PDF changes    
     
        
COMMIT        
 END TRY        
    BEGIN CATCH        
  IF @@TRANCOUNT > 0        
  BEGIN        
  ROLLBACK        
  exec dbo.sp_KvtErrorLogging         
  END;        
  THROW;        
 END CATCH          
           
END    
    
--exec sp_GenerateSalaryPDFbyID @id = 21, @uuid = 'a77a60e5-3199-4770-24ab-08db4d498356'

----------------------------------------------------------------------------------------------------------------

/****** Object:  StoredProcedure [dbo].[sp_GetDebtControlInvoice]    Script Date: 02/06/2023 12.19.12 ******/
SET ANSI_NULLS ON
