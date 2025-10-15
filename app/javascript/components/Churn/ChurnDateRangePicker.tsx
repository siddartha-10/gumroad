import { subDays } from "date-fns";
import * as React from "react";

import { DateInput } from "$app/components/DateInput";
import { Icon } from "$app/components/Icons";
import { Popover } from "$app/components/Popover";
import { useUserAgentInfo } from "$app/components/UserAgent";

const MAX_DAYS = 30;

export const ChurnDateRangePicker = ({
  from,
  to,
  setFrom,
  setTo,
}: {
  from: Date;
  to: Date;
  setFrom: (from: Date) => void;
  setTo: (to: Date) => void;
}) => {
  const today = new Date();
  const uid = React.useId();
  const [isCustom, setIsCustom] = React.useState(false);
  const [open, setOpen] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const { locale } = useUserAgentInfo();

  const validateDateRange = (newFrom: Date, newTo: Date): boolean => {
    const days = Math.ceil((newTo.getTime() - newFrom.getTime()) / (1000 * 60 * 60 * 24)) + 1;
    if (days > MAX_DAYS) {
      setError(`Date range cannot exceed ${MAX_DAYS} days. Selected: ${days} days`);
      return false;
    }
    setError(null);
    return true;
  };

  const quickSet = (from: Date, to: Date) => {
    if (validateDateRange(from, to)) {
      setFrom(from);
      setTo(to);
      setOpen(false);
    }
  };

  const handleFromChange = (date: Date | null) => {
    if (date && validateDateRange(date, to)) {
      setFrom(date);
    }
  };

  const handleToChange = (date: Date | null) => {
    if (date && validateDateRange(from, date)) {
      setTo(date);
    }
  };

  return (
    <Popover
      open={open}
      onToggle={(open) => {
        setIsCustom(false);
        setError(null);
        setOpen(open);
      }}
      trigger={
        <div className="input" aria-label="Date range selector">
          <span suppressHydrationWarning>{Intl.DateTimeFormat(locale).formatRange(from, to)}</span>
          <Icon name="outline-cheveron-down" className="ml-auto" />
        </div>
      }
    >
      {isCustom ? (
        <div className="paragraphs">
          <fieldset>
            <legend>
              <label htmlFor={`${uid}-from`}>From (including)</label>
            </legend>
            <DateInput
              id={`${uid}-from`}
              value={from}
              onChange={handleFromChange}
            />
          </fieldset>
          <fieldset>
            <legend>
              <label htmlFor={`${uid}-to`}>To (including)</label>
            </legend>
            <DateInput
              id={`${uid}-to`}
              value={to}
              onChange={handleToChange}
            />
          </fieldset>
          {error && (
            <div className="text-red-600 text-sm">
              {error}
            </div>
          )}
        </div>
      ) : (
        <div role="menu">
          <div role="menuitem" onClick={() => quickSet(subDays(today, 29), today)}>
            Last 30 days
          </div>
          <div role="menuitem" onClick={() => setIsCustom(true)}>
            Custom range...
          </div>
        </div>
      )}
    </Popover>
  );
};
