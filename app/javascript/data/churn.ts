export type ChurnMetrics = {
  customer_churn_rate: number;
  last_period_churn_rate: number;
  churned_subscribers: number;
  churned_mrr_cents: number;
};

export type ChurnDailyData = {
  date: string;
  customer_churn_rate: number;
  churned_subscribers: number;
  churned_mrr_cents: number;
};

export type ChurnData = {
  start_date: string;
  end_date: string;
  metrics: ChurnMetrics;
  daily_data: ChurnDailyData[];
};
