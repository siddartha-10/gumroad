import * as React from "react";

import { useClientAlert } from "$app/components/ClientAlertProvider";
import { DateRangePicker } from "$app/components/DateRangePicker";

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
  const { showAlert } = useClientAlert();
  const pendingRef = React.useRef<{ from?: Date; to?: Date }>({});
  const timeoutRef = React.useRef<number | null>(null);

  const validateAndApply = React.useCallback(() => {
    const finalFrom = pendingRef.current.from ?? from;
    const finalTo = pendingRef.current.to ?? to;
    pendingRef.current = {};

    // Normalize dates to start of day to avoid timezone/time-of-day issues
    const normalizedFrom = new Date(finalFrom.getFullYear(), finalFrom.getMonth(), finalFrom.getDate());
    const normalizedTo = new Date(finalTo.getFullYear(), finalTo.getMonth(), finalTo.getDate());
    const days = Math.round((normalizedTo.getTime() - normalizedFrom.getTime()) / (1000 * 60 * 60 * 24));

    if (finalFrom > finalTo) {
      showAlert("Invalid date range: start date must be before end date.", "error");
    } else if (days > MAX_DAYS) {
      showAlert(`Date range cannot exceed ${MAX_DAYS} days. Selected: ${days} days.`, "error");
    } else {
      setFrom(finalFrom);
      setTo(finalTo);
    }
  }, [from, to, setFrom, setTo, showAlert]);

  const scheduleValidation = React.useCallback(() => {
    if (timeoutRef.current !== null) {
      window.clearTimeout(timeoutRef.current);
    }
    timeoutRef.current = window.setTimeout(validateAndApply, 0);
  }, [validateAndApply]);

  const handleSetFrom = React.useCallback((newFrom: Date) => {
    pendingRef.current.from = newFrom;
    scheduleValidation();
  }, [scheduleValidation]);

  const handleSetTo = React.useCallback((newTo: Date) => {
    pendingRef.current.to = newTo;
    scheduleValidation();
  }, [scheduleValidation]);

  return (
    <DateRangePicker
      from={from}
      to={to}
      setFrom={handleSetFrom}
      setTo={handleSetTo}
    />
  );
};
