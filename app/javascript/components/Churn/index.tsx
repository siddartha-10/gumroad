import { lightFormat } from "date-fns";
import * as React from "react";

import { fetchChurnData, type ChurnData } from "$app/data/churn";
import { AbortError } from "$app/utils/request";

import { AnalyticsLayout } from "$app/components/Analytics/AnalyticsLayout";
import { ProductsPopover } from "$app/components/Analytics/ProductsPopover";
import { useAnalyticsDateRange } from "$app/components/Analytics/useAnalyticsDateRange";
import { ChurnChart } from "$app/components/Churn/ChurnChart";
import { ChurnQuickStats } from "$app/components/Churn/ChurnQuickStats";
import { DateRangePicker } from "$app/components/DateRangePicker";
import { Progress } from "$app/components/Progress";
import { showAlert } from "$app/components/server-components/Alert";

import placeholder from "$assets/images/placeholders/sales.png";

export type ChurnProps = {
  has_subscription_products: boolean;
  products: { name: string; id: string; alive: boolean; unique_permalink: string }[];
};

const Churn = ({ has_subscription_products, products: initialProducts }: ChurnProps) => {
  const dateRange = useAnalyticsDateRange();
  const [data, setData] = React.useState<ChurnData | null>(null);
  const [aggregateBy, setAggregateBy] = React.useState<"day" | "month">("day");
  const [products, setProducts] = React.useState(initialProducts.map((p) => ({ ...p, selected: p.alive })));

  const startTime = lightFormat(dateRange.from, "yyyy-MM-dd");
  const endTime = lightFormat(dateRange.to, "yyyy-MM-dd");

  const hasContent = has_subscription_products;
  const selectedProductIds = React.useMemo(() => products.filter((p) => p.selected).map((p) => p.id), [products]);

  const activeRequest = React.useRef<AbortController | null>(null);

  React.useEffect(() => {
    const loadData = async () => {
      if (!hasContent) return;

      try {
        if (activeRequest.current) {
          activeRequest.current.abort();
        }

        setData(null);

        const request = fetchChurnData({ startTime, endTime, aggregateBy, productIds: selectedProductIds });
        activeRequest.current = request.abort;

        const result = await request.response;
        setData(result);
        activeRequest.current = null;
      } catch (e) {
        if (e instanceof AbortError) return;
        showAlert("Sorry, something went wrong. Please try again.", "error");
      }
    };

    void loadData();
  }, [startTime, endTime, aggregateBy, selectedProductIds, hasContent]);

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
            <DateRangePicker {...dateRange} />
          </>
        ) : null
      }
    >
      {hasContent ? (
        <div className="space-y-8 p-4 md:p-8">
          <ChurnQuickStats metrics={data?.metrics} />
          {data ? (
            <ChurnChart data={data.daily_data} aggregateBy={aggregateBy} />
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
