# Luxembourg Digital Mobility Observatory — BI Pipeline & Predictive Analytics

**Role:** Business Intelligence Analyst — EDDA Luxembourg, Feb–Aug 2024

Automated the mobility data pipeline for Luxembourg's Digital Mobility Observatory — turning a manual process (1+ year data lag) into an always-current system with interactive dashboards and traffic forecasting.

## Workflow

```
data.public.lu (Open Government API)
        │
        ▼
   Talend  →  extract & load raw data
        │
        ▼
   MySQL   →  staging → ODS (clean, standardize, historize)
        │
        ▼
   Denodo  →  data virtualization, star/snowflake schema
        │
        ▼
  ┌──────┴──────┐
  ▼             ▼
Power BI     Python
(dashboards) (Random Forest / ARIMA
              traffic forecasting)
```

**Tech stack:** Talend Studio · MySQL Workbench · Denodo · Power BI · Python (pandas, scikit-learn, statsmodels) · Jupyter Notebook

## Dashboards

### Traffic
![Traffic Dashboard](./images/traffic_dashboard.png)
Average traffic by year, vehicle type, and location — broken down by month, day of week, hour, and quarter. Filterable to individual counting stations.

### Vehicle Fleet
![Fleet Dashboard](./images/fleet_dashboard.png)
457,750 registered vehicles, filterable by year, month, and vehicle category — breakdown by country of origin, color, manufacturer/model, and fuel type.

### EV Charging Stations
![EV Charging Dashboard](./images/ev_charging_dashboard.png)
Live-derived stats from 5-minute connector polling: 1,655 standard chargers vs. 69 fast chargers, vehicles recharged, and theoretical max electricity delivered.

## Key Numbers

- 457,750 vehicles in the national fleet
- 16.7K avg. daily traffic (weekdays) vs. 9.5K (weekends)
- 1,655 standard EV chargers vs. 69 fast chargers
- Random Forest traffic forecast: R² up to 0.83

## Notes

Data source is open government data (`data.public.lu`), so the pipeline, dashboards, and results here are fully shareable. Internal implementation details specific to the client environment (Talend job configs, internal schema names) are omitted for confidentiality.
