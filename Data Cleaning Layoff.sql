-- Cleaning Data Project

select * 
from layoffs
-- WE Need to:
-- 1 remove duplicates -- 2 standardize the data -- 3 null and blanck values -- 4 remove unnecessary colums rows



-- 1 remove duplicates
-- Create staging table to keep raw data apart
create table layoffs_staging
like layoffs

insert into layoffs_staging
select * from layoffs

select *, row_number() over
( partition by company, industry, location, country, stage, funds_raised_millions ,total_laid_off ,percentage_laid_off,  `date`) as row_num
from layoffs_staging 

-- add the row_num into a cte so we can inspect results after
with dupcte as (
select *, row_number() over
( partition by company, industry, location, country, stage, funds_raised_millions, total_laid_off ,percentage_laid_off,  `date`) as row_num
from layoffs_staging 
)

select * from dupcte 
where row_num  >1

-- creating staging2 while adding an additional column so we can remove duplicates
CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  row_num int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


insert into layoffs_staging2
select *, row_number() over
( partition by company, industry, location, country, stage, funds_raised_millions, total_laid_off ,percentage_laid_off,  `date`) as row_num
from layoffs_staging 

select* from layoffs_staging2
where row_num >1

delete from layoffs_staging2
WHERE row_num >1;
-- Now we removed every duplicate row




-- 2 standardizing data
select * from layoffs_staging2
select company, trim(company) from layoffs_staging2

-- removing blank space
update layoffs_staging2
set company = trim(company)

select distinct(industry) from layoffs_staging2
order by industry
-- we find that crypto, cryptocurrency is the same so lets standardize
-- Checking which one is more 
select * from layoffs_staging2
where industry like 'crypto%'
-- we found that majority are crypto and not cryptocurrency or crypto currency so we will fix all to crypto

Update layoffs_staging2
set industry ='Crypto' 
where industry like 'crypto%'


select distinct country from layoffs_staging2
order by 1
-- Found united states.
select * from layoffs_staging2
where country like 'united states%'

update layoffs_staging2
set country = 'United States'
where country like 'united states%'

-- fix the type of data for date
select `date`, str_to_date(`date`,'%m/%d/%Y')
from layoffs_staging2

update layoffs_staging2
set `date` = str_to_date(`date`,'%m/%d/%Y')

-- now lets convert that column to date instead of text
Alter table layoffs_staging2
modify column `date` date

-- 3 null and blanck values 
select * from layoffs_staging2
where percentage_laid_off is null
and total_laid_off is null
-- checking for null but we will not do anything about this for now

-- lets see with industry
select * from layoffs_staging2
where industry is null or industry =''
-- Try to populate missing values if possible
select * from layoffs_staging2 where company='Airbnb' -- looks like industry for airbnb is travel accoring to another column

-- we will check for all columns that are missing industry 
select t1.industry, t2.industry
from layoffs_staging2 t1
join layoffs_staging2 t2 
on t1.company = t2.company
where (t1.industry is null or t1.industry='')
and t2.industry is not null;

-- lets make all blank null first
update layoffs_staging2
set industry = null 
where industry=''


update layoffs_staging2 t1
join layoffs_staging2 t2 
on t1.company = t2.company
	set t1.industry = t2.industry
    where (t1.industry is null)
		and t2.industry is not null;
        
 -- we populated blank and null values of industry where another raw with same company had an industry
 
 -- 4 remove unnecessary colums rows
 select * from layoffs_staging2
 where total_laid_off is null
	and percentage_laid_off is null;
 -- in this case we believe that when percentage_laid_off and total_laid_off are both null, the data has no value so we will remove
 
Delete from 
layoffs_staging2
where total_laid_off is null
	and percentage_laid_off is null;
-- we will also remove the column row_num , we don't need it
Alter table layoffs_staging2
drop column row_num;

