import { router, usePage } from "@inertiajs/react";
import { lightFormat } from "date-fns";
import * as React from "react";

import type { ChurnData } from "$app/data/churn";

import { AnalyticsLayout } from "$app/components/Analytics/AnalyticsLayout";
import { ProductsPopover } from "$app/components/Analytics/ProductsPopover";
import { useAnalyticsDateRange } from "$app/components/Analytics/useAnalyticsDateRange";
import { ChurnChart } from "$app/components/Churn/ChurnChart";
import { ChurnDateRangePicker } from "$app/components/Churn/ChurnDateRangePicker";
import { ChurnQuickStats } from "$app/components/Churn/ChurnQuickStats";
import { Progress } from "$app/components/Progress";

import placeholder from "$assets/images/placeholders/sales.png";

export type ChurnProps = {
  has_subscription_products: boolean;
  products: { name: string; id: string; alive: boolean; unique_permalink: string }[];
};

const Churn = ({ has_subscription_products, products: initialProducts }: ChurnProps) => {
  const dateRange = useAnalyticsDateRange();
  const [aggregateBy, setAggregateBy] = React.useState<"day" | "month">("day");
  const [products, setProducts] = React.useState(initialProducts.map((p) => ({ ...p, selected: p.alive })));
  const [isLoading, setIsLoading] = React.useState(false);

  const { churn_data } = usePage<{ churn_data?: ChurnData }>().props;

  const startTime = lightFormat(dateRange.from, "yyyy-MM-dd");
  const endTime = lightFormat(dateRange.to, "yyyy-MM-dd");

  const hasContent = has_subscription_products;
  const selectedProductIds = React.useMemo(() => products.filter((p) => p.selected).map((p) => p.id), [products]);

  // Validate date range before making backend call
  const isValidDateRange = React.useMemo(() => {
    // Normalize dates to start of day to avoid timezone/time-of-day issues
    const normalizedFrom = new Date(dateRange.from.getFullYear(), dateRange.from.getMonth(), dateRange.from.getDate());
    const normalizedTo = new Date(dateRange.to.getFullYear(), dateRange.to.getMonth(), dateRange.to.getDate());
    const days = Math.round((normalizedTo.getTime() - normalizedFrom.getTime()) / (1000 * 60 * 60 * 24));
    return dateRange.from <= dateRange.to && days <= 30;
  }, [dateRange.from, dateRange.to]);

  React.useEffect(() => {
    if (!hasContent || !isValidDateRange) return;

    setIsLoading(true);

    // Use Inertia's partial reload to fetch only churn_data
    // Send special marker "none" when no products are selected to distinguish from "not provided"
    const productIdsData = selectedProductIds.length > 0
      ? { product_ids: selectedProductIds }
      : { product_ids: ["none"] };

    router.reload({
      only: ["churn_data"],
      data: {
        start_time: startTime,
        end_time: endTime,
        aggregate_by: aggregateBy,
        ...productIdsData,
      },
      onFinish: () => {
        setIsLoading(false);
      },
    });
  }, [startTime, endTime, aggregateBy, selectedProductIds, hasContent, isValidDateRange]);

  return (
    <AnalyticsLayout
      selectedTab="churn"
      actions={
        hasContent ? (
          <>
            <select
              aria-label="Aggregate by"
              className="w-auto"
              value={aggregateBy}
              onChange={(e) => {
                const value = e.target.value;
                if (value === "day" || value === "month") setAggregateBy(value);
              }}
            >
              <option value="day">Daily</option>
              <option value="month">Monthly</option>
            </select>
            <ProductsPopover products={products} setProducts={setProducts} />
            <ChurnDateRangePicker {...dateRange} />
          </>
        ) : null
      }
    >
      {hasContent ? (
        <div className="space-y-8 p-4 md:p-8">
          <ChurnQuickStats metrics={churn_data?.metrics} />
          {churn_data?.daily_data && !isLoading ? (
            <ChurnChart data={churn_data.daily_data} aggregateBy={aggregateBy} />
          ) : (
            <div className="input">
              <Progress width="1em" />
              Loading charts...
            </div>
          )}
        </div>
      ) : (
        <div className="p-4 md:p-8">
          <div className="placeholder">
            <figure>
              <img src={placeholder} />
            </figure>
            <h2>No subscription products yet</h2>
            <p>
              Churn analytics are available for creators with active subscription products. Create a membership or
              subscription product to start tracking subscriber retention.
            </p>
            <a href={Routes.help_center_article_path("172-memberships")} target="_blank" rel="noreferrer">
              Learn more about memberships
            </a>
          </div>
        </div>
      )}
    </AnalyticsLayout>
  );
};

export default Churn;
