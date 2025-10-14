import { cast } from "ts-safe-cast";

import { request } from "$app/utils/request";

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

export const fetchChurnData = ({
  startTime,
  endTime,
  aggregateBy = "day",
  productIds,
}: {
  startTime: string;
  endTime: string;
  aggregateBy?: "day" | "month";
  productIds?: string[];
}): { response: Promise<ChurnData>; abort: AbortController } => {
  const abort = new AbortController();

  const response = request({
    method: "GET",
    accept: "json",
    url: Routes.churn_data_path({
      start_time: startTime,
      end_time: endTime,
      aggregate_by: aggregateBy,
      ...(productIds && productIds.length > 0 ? { product_ids: productIds } : {}),
    }),
    abortSignal: abort.signal,
  })
    .then((r) => r.json())
    .then((json) => cast<ChurnData>(json));

  return { response, abort };
};
